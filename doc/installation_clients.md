Installation Clients
======================
Installation uses some special clients for inst modules. Goal of this
article is to introduce which one is needed for each task


Module in Wizard (`inst_` client)
-----------------------------------------

When new module should be in full screen in installation work-flow, then
client with `inst_` prefix is by default used, but in general can be any client.
It need to be added to control file to (work-flow section)[TODO link].

Module in Installation Summary (`_proposal` client)
-----------------------------------------------------------

When new module should be seen only on summary page or in different proposal screen,
then client with suffix `_proposal` is used. Such client must accept string as first
parameter which specify action that must be performed and map as second parameter
for possible arguments. It must be specified in control file in (proposal section)[TODO link].
Actions can be:

- `"MakeProposal"` that create proposal for module. Can have parameter `"force_reset"`
  that can force proposal even if already done. Response is hash with proposal text,
  links that are available there and own help text. TODO specify exactly format.
- `"AskUser"` for automatic or manual user request to change value. Parameter is
  `"chosen_id"` which specify action. It can be `"id"` from `"Description"` action
  which should open dialog to modify values or links specified in `"MakeProposal"`
  which should do action depending on link like disable service. Returns if proposal changed. TODO exact structure
- `"Description"` to get description of proposal in rich text, as menu item and its `"id"`.
  TODO describe here exact structure and examples
- `"Write"` to write settings. Called only if proposal is not skipped. TODO looks like now all proposals are skipped

Final Write of Module (`_finish` client )
--------------------------------------------

When module need to write its settings at the end of installation, then
client with suffix `_finish` is used. Such client must accept string as first
parameter which specify action that must be performed. It must be specified in
inst_finish.rb client.
Actions can be:

- `"Info"` that gets information about client like number of steps, its title
  and in which mode it should be used.create proposal for module. TODO exact structure and example
- `"Write"` to write settings.
