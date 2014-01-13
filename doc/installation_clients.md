Installation Clients
======================

Installation uses some special clients for inst modules. The goal of this
article is to describe which one is needed for each task.


Wizard Plug-in (`inst_` client)
-----------------------------------------

When a new dialog needs to be added into the installation work-flow then a new
client with `inst_` prefix needs to be created. (In general it can be any
client, this is a convention. The work-flow manager can find also the clients
without the prefix.)

The new client needs to be added to the installation control file to (the work-flow
section)[TODO link], and the file must be present in the inst-sys during
installation. (It can be part of the inst-sys or it can be added dynamically
from an add-on media or via (Driver Update)[http://en.opensuse.org/SDB:Linuxrc#p_dud])


Installation Summary Plug-in (`_proposal` client)
-----------------------------------------------------------

When a new module should be seen only in the installation summary page or in a
different proposal screen, then a client with suffix `_proposal` is used. Such
client must accept string as the first parameter which specifies the action
which is being performed and a `Hash` as the second parameter with optional
arguments.

The proposals are defined in the installation control file in (the proposal
section)[TODO link].

The actions can be:

- `"MakeProposal"` that creates a proposal for the module. It can have parameter `"force_reset"`
  that can force reset and create a new one from scratch. Response is a `Hash` with proposal text,
  optional link definitions and a help text. **TODO specify exactly format.**
- `"AskUser"` for automatic or manual user request to change the proposed configuration. Parameter is
  `"chosen_id"` which specify action. It can be `"id"` from `"Description"` action
  which should open dialog to modify values or links specified in `"MakeProposal"`
  which should do action depending on link like disable service. Returns if proposal changed. **TODO exact structure**
- `"Description"` to get the description of the proposal in rich text, menu item and its `"id"`.
  **TODO describe here exact structure and examples**
- `"Write"` to write the settings. Called only if the proposal is not skipped. **TODO looks like now all proposals are skipped**


Final Write of Plug-in (`_finish` client )
--------------------------------------------

When a module needs to write its settings at the end of installation then a
client with suffix `_finish` is used. Such client must accept string as the
first parameter which specifies the action that is being performed.

The list finish clients is specified in `inst_finish.rb` client.

Actions can be:

- `"Info"` that gets the information about client (like number of steps, its title
  and in which mode it should be used). **TODO exact structure and example**
- `"Write"` to write the settings.
