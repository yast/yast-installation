Installation Images
===================

Installation images are used to speed installation up. Each separate
image contains a compact part of a filesystem. Several images can be
combined together to finally create several different complete systems -
the only unique image for each such system is a separate image
containing RPM (plus other metadata) database for a particular system.

Example of images on media:

    Available Images:
      * Base_System
      * Xorg
      * Additional_Tools
      * Metadata_image_*, one for each imageset

Example of imagesets (combinations of images):

    Base System:
      + Base_System
      + Metadata_image_1 (Base_System.meta)

    Advanced System:
      + Base_System
      + Xorg
      + Metadata_image_2 (Base_System.meta + Xorg.meta)

    Superadvanced System
      + Base_System
      + Xorg
      + Additional_Tools
      + Metadata_image_3 (Base_System.meta + Xorg.meta + Additional_Tools.meta)

Supported Types of Images
-------------------------

-   *\*.lzma* (((files)tar)lzma) - TAR\* archive additionally compressed
    with LZMA

-   *\*.xz* - (((files)tar)lzma) - TAR\* archive additionally compressed
    with newer LZMA

-   *\*.tar.bzip2, \*.tar.gz* (((files)tar)bzip2/gzip) - TAR\*/Bzip2;
    resp. TAR\*/Gzip archive

\* Each TAR archive is created with: *--numeric-owner --checkpoint=400
--record-size=10240*

Imagesets Description
---------------------

If we want to use installation images, we have to describe them first.
See the [example of file](inst_images/images.xml.example) stored on the first
installation media:

This XML file describes sets of images from which an installation
chooses the best-matching one according to \<patterns\>...\</patterns\>
item defined in each *imageset*.

Images Details
--------------

Each imageset contains one or more images. To provide a useful feedback
when deploying the images, they have to be described in
*/images/details-$ARCH.xml*, respectively in file
*/images/details.xml* stored on the first installation media:

*$ARCH* is any architecture recognized by Yast see [Arch library in yast2]
(https://github.com/yast/yast-yast2/blob/master/library/general/src/modules/Arch.rb).
Mandatary items for each *image* (file name) are *file* and *size* (in
bytes).
