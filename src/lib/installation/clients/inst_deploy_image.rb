# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

module Yast
  class InstDeployImageClient < Client
    include Yast::Logger

    def main
      Yast.import "Pkg"
      Yast.import "Installation"
      Yast.import "ImageInstallation"
      Yast.import "Progress"
      Yast.import "Wizard"
      Yast.import "SourceManager"
      Yast.import "String"
      Yast.import "PackageCallbacks"
      Yast.import "SlideShow"
      Yast.import "Report"
      Yast.import "ProductFeatures"
      Yast.import "PackagesUI"
      Yast.import "Misc"

      textdomain "installation"

      # OEM image if target disk is defined
      oem_image = !InstData.image_target_disk.nil?

      if oem_image
        path = ProductFeatures.GetStringFeature("globals", "oem_image")
        ImageInstallation.PrepareOEMImage(path)
        Misc.boot_msg = _("The system will reboot now...")
      # There is nothing to do
      elsif !Installation.image_installation
        Builtins.y2milestone("No images have been selected")
        # bnc #395030
        # Use less memory
        ImageInstallation.FreeInternalVariables
        return :auto
      end

      Builtins.y2milestone("Deploying images")

      SlideShow.MoveToStage("images")

      @images = ImageInstallation.ImageOrder

      @last_image = nil

      @_last_download_progress = -1

      @_current_overall_progress = 0
      @_last_overall_progress = -1

      @_current_subprogress_start = 0
      @_current_subprogress_steps = 0
      @_current_subprogress_total = 0

      @_current_step_in_subprogress = 0

      @_previous_id = nil

      @_steps_for_one_image = 100
      @download_handler_hit = false
      @_last_image_downloading = nil
      @report_image_downloading = false

      @_last_progress = -1
      @_last_image_id = nil

      ImageInstallation.SetDeployTarImageProgress(
        fun_ref(method(:SetOneImageProgress), "void (integer)")
      )
      ImageInstallation.SetDownloadTarImageProgress(
        fun_ref(
          method(:MyProgressDownloadHandler),
          "boolean (integer, integer, integer)"
        )
      )
      ImageInstallation.SetStartDownloadImageProgress(
        fun_ref(method(:MyStartDownloadHandler), "void (string, string)")
      )
      ImageInstallation.SetOverallDeployingProgress(
        fun_ref(method(:OverallProgressHandler), "void (string, integer)")
      )

      ImageInstallation.AdjustProgressLayout(
        "deploying_images",
        Ops.multiply(@_steps_for_one_image, Builtins.size(@images)),
        _("Deploying Images...")
      )

      # Wizard::SetContents (
      #     _("Deploying Installation Images"),
      #     `VBox (
      #   `ProgressBar (
      #       `id ("one_image"),
      #       _("Initializing..."),
      #       100,
      #       0
      #   ),
      #   `ProgressBar (
      #       `id ("deploying_progress"),
      #       _("Deploying Images..."),
      #       100,
      #       0
      #   )
      #     ),
      #     // TRANSLATORS: help idi#1
      #     _("<p>System images are being deployed. Please wait...</p>") +
      #
      #     // TRANSLATORS: help idi#2
      #     _("<p>Installation images are part of the installation media.</p>") +
      #
      #     // TRANSLATORS: help idi#3
      #     _("<p>Installation from images is faster than installation from RPM packages
      # because it does not need to interact with a RPM database, locks etc.
      # One of the images also contains the joint RPM database and other metadata.</p>
      # ") +
      #
      #     // TRANSLATORS: help idi#4
      #     _("<p>If there is no direct access to installation images,
      # the installation program has to download them first before they are deployed.</p>
      # "),
      #     false, false
      # );

      # Stores all states of resolvables
      ImageInstallation.StoreAllChanges

      # Reset libzypp
      Pkg.TargetFinish

      # in case of OEM image deployment, there is no disk available
      if oem_image
        target = InstData.image_target_disk
      else
        # Set where the images will be downloaded
        SourceManager.InstInitSourceMoveDownloadArea
        target = Installation.destdir
      end
      @dep_ret = ImageInstallation.DeployImages(@images, target, nil)
      Builtins.y2milestone("DeployImages returned: %1", @dep_ret)

      # BNC #444209
      # false == error
      if @dep_ret == false
        Report.Error(
          _("Deploying images has failed.\nAborting the installation...\n")
        )
        Builtins.y2milestone("Aborting...")
        return :abort
        # nil   == aborted
      elsif @dep_ret.nil?
        Builtins.y2milestone("Aborting...")
        return :abort
      end

      Builtins.y2milestone("Target image for package selector prepared")

      # Load the libzypp state from the system (with images deployed)
      PackageCallbacks.RegisterEmptyProgressCallbacks
      if oem_image
        # TODO: later when adding more functionality: mount the deployed image for inst_finish
      else
        Pkg.TargetInitialize(Installation.destdir)
        Pkg.TargetLoad
        PackageCallbacks.RestorePreviousProgressCallbacks
      end

      # Restore the states stored by StoreAllChanges()
      if ImageInstallation.RestoreAllChanges != true
        Builtins.y2warning("Aborting...")
        return :abort
      end

      # BNC #436842 - debug feature in control file
      if ProductFeatures.GetBooleanFeature("globals", "debug_deploying") == true
        # TRANSLATORS: pop-up message
        Report.Message(
          _(
            "Debugging has been turned on.\nYaST will open a software manager for you to check the current status of packages."
          )
        )
        RunPackageManager()
      end

      # bnc #395030
      # Use less memory
      ImageInstallation.FreeInternalVariables

      :next
    end

    def SetProgress
      percent = Ops.divide(
        Ops.multiply(100, @_current_step_in_subprogress),
        @_current_subprogress_total
      )
      SlideShow.SubProgress(percent, nil)

      nil
    end

    def OverallProgressHandler(id, current_step)
      # new set of steps
      if @_previous_id != id
        # reset steps in subprogress
        @_current_step_in_subprogress = 0

        # new settings for new step
        @_current_subprogress_start = ImageInstallation.GetProgressLayoutDetails(
          id,
          "steps_start_at"
        )
        @_current_subprogress_steps = ImageInstallation.GetProgressLayoutDetails(
          id,
          "steps_reserved"
        )
        @_current_subprogress_total = ImageInstallation.GetProgressLayoutDetails(
          id,
          "steps_total"
        )

        # div by zero!
        if @_current_subprogress_total == 0
          Builtins.y2error("steps_total=0")
          @_current_subprogress_total = 1
        end

        Builtins.y2milestone(
          "New overall progress ID: %1 (steps_start_at: %2, steps_reserved: %3, steps_total: %4)",
          id,
          @_current_subprogress_start,
          @_current_subprogress_steps,
          @_current_subprogress_total
        )

        # when deploying images, label is handled separately
        if id != "deploying_images"
          new_label = ImageInstallation.GetProgressLayoutLabel(id)
          SlideShow.SubProgressStart(new_label)
        end

        @_previous_id = id
      end

      # incremental
      @_current_step_in_subprogress = if current_step.nil?
        Ops.add(
          @_current_step_in_subprogress,
          1
        )
        # set to exact number
      else
        current_step
      end

      SetProgress() if ["storing_user_prefs", "restoring_user_prefs"].include?(id)

      # Should be 0 - 100%
      @_current_overall_progress = Ops.add(
        @_current_subprogress_start,
        Ops.divide(
          Ops.multiply(
            @_current_subprogress_steps,
            @_current_step_in_subprogress
          ),
          @_current_subprogress_total
        )
      )

      # update UI only if nr% has changed
      if Ops.greater_than(@_current_overall_progress, @_last_overall_progress)
        @_last_overall_progress = @_current_overall_progress
        SlideShow.StageProgress(@_current_overall_progress, nil)
      end

      nil
    end

    # Not only images but also some helper files are downloaded
    # Image installation should report only images
    # BNC #449792
    def MyStartDownloadHandler(url, _localfile)
      current_image = ImageInstallation.GetCurrentImageDetails
      current_image_file = Ops.get_string(current_image, "file", "")

      # Fetches is (additionally) downloading some other file
      if current_image_file.nil? || current_image_file == ""
        Builtins.y2warning("Uknown image being downloaded: %1", current_image)
        @report_image_downloading = false
        return
      end

      image_filename_length = Builtins.size(current_image_file)
      # 'http://some.url/directory/image.name' vs. 'directory/image.name'
      image_url_download = Builtins.substring(
        url,
        Ops.subtract(Builtins.size(url), image_filename_length),
        image_filename_length
      )

      # downloading progress is reported only if
      @report_image_downloading = image_url_download == current_image_file

      Builtins.y2milestone(
        "Downloading started %1, showing progress %2",
        url,
        @report_image_downloading
      )

      nil
    end

    def MyProgressDownloadHandler(percent, _bps_avg, bps_current)
      # changing settings on the fly
      # ... first when download handler is hit
      #
      # if a repository is remote, there are twice more steps to do (download, deploy)
      # local (or NFS, SMB, ...) access do not use downloader
      if !@download_handler_hit
        Builtins.y2milestone("DownloadHandler - first hit")
        # twice more steps
        ImageInstallation.AdjustProgressLayout(
          "deploying_images",
          Ops.multiply(
            Ops.multiply(2, @_steps_for_one_image),
            Builtins.size(@images)
          ),
          _("Deploying Images...")
        )
        @download_handler_hit = true
      end

      # See MyStartDownloadHandler
      # BNC #449792
      return true if @report_image_downloading != true

      current_image = ImageInstallation.GetCurrentImageDetails

      if Ops.less_than(@_last_download_progress, percent)
        image_info = Ops.get_string(current_image, "name", "")

        # BNC 442286, new image
        # Sometimes it happens that the same image is logged twice
        if @_last_image_downloading != image_info
          Builtins.y2milestone("Downloading image: %1", image_info)
          @_last_image_downloading = image_info
        end

        # unknown image
        image_info = if image_info == ""
          Builtins.sformat(
            _("Downloading image at speed %1/s"),
            String.FormatSize(bps_current)
          )
        else
          Builtins.sformat(
            _("Downloading image %1 at speed %2/s"),
            image_info,
            String.FormatSize(bps_current)
          )
        end

        SlideShow.SubProgress(percent, image_info)

        current_image_nr = Ops.get_integer(current_image, "image_nr", 0)
        current_steps = if @download_handler_hit
          Ops.add(
            Ops.multiply(
              Ops.multiply(current_image_nr, 2),
              @_steps_for_one_image
            ),
            percent
          )
        else
          Ops.add(
            Ops.multiply(current_image_nr, @_steps_for_one_image),
            percent
          )
        end

        OverallProgressHandler("deploying_images", current_steps)
      end

      @_last_download_progress = percent

      true
    end

    def SetOneImageProgress(current_progress)
      current_image = ImageInstallation.GetCurrentImageDetails
      max_progress = Ops.get_integer(current_image, "max_progress", 0)

      another_image = false

      # another file than the previous one
      if Ops.get_string(current_image, "file", "") != @_last_image_id
        another_image = true
        @_last_image_id = Ops.get_string(current_image, "file", "")
        @_last_download_progress = -1
        @_last_progress = -1
      end

      if max_progress.nil? || max_progress == 0
        Builtins.y2milestone("Can't find max_progress: %1", current_image)
        return
      end

      # current progress 0 - 100
      x_progress = Ops.divide(Ops.multiply(100, current_progress), max_progress)
      x_progress = 100 if Ops.greater_than(x_progress, 100)

      # reset the label
      if x_progress == 0
        current_image_name = Ops.get_string(current_image, "name", "")

        current_image_name = if current_image_name == ""
          _("Deploying image...")
        else
          Builtins.sformat(
            _("Deploying image %1..."),
            current_image_name
          )
        end

        if another_image == true
          # one image done (another than the previous one)
          # BNC #442286
          SlideShow.SubProgressStart(current_image_name)
          SlideShow.AppendMessageToInstLog(current_image_name)
        else
          Builtins.y2warning(
            "The same image name again: %1 (100 * %2 / %3)",
            current_image_name,
            current_progress,
            max_progress
          )
        end
      end

      # set current step
      if Ops.greater_than(x_progress, @_last_progress)
        SlideShow.SubProgress(x_progress, nil)
        @_last_progress = x_progress
        current_image_nr = Ops.get_integer(current_image, "image_nr", 0)
        current_steps = if @download_handler_hit
          Ops.add(
            Ops.multiply(
              Ops.add(Ops.multiply(current_image_nr, 2), 1),
              @_steps_for_one_image
            ),
            x_progress
          )
        else
          Ops.add(
            Ops.multiply(current_image_nr, @_steps_for_one_image),
            x_progress
          )
        end

        OverallProgressHandler("deploying_images", current_steps)
      end

      nil
    end

    def RunPackageManager
      Builtins.y2milestone("--- running the package manager ---")
      PackagesUI.RunPackageSelector("mode" => :summaryMode)
      Builtins.y2milestone("--- running the package manager ---")

      nil
    end
  end
end
