0.3.5   bug in verify_session fixed

0.3.1   ex_doc in dev mode only.

0.2.24  Timex/tzdata dependency removed. All times in the ACS are UTC anyway, so it
        was never really needed.

0.2.23  Fixed a bug - the terminate/2 reason in the session can be a non-string

0.2.22  Improved handling of unexpected read_body results in the CWMP parser.

0.2.21  Now possible to configure a list of ACS ports to listen to.

0.2.20  All messages now has a default value for id in the header when construct replies, in case of
        the header being nil or otherwise defunct.

0.2.19  session has to handle an Inform with no SOAP header, and this no requesting ID. We just reply with 0 as id
        because such an Inform would mean that the device dont care about such things, so we can reply whatever
        we like.

0.2.18  Minor bug fix - the session_filter need only the inform data hd(:entries) not the complete envelope as param 2

0.2.17  The session_filter method needs the inform aswell, because it might need to inspect
        further into the inform parameters in order to auth a device. Specifically in case
        of "TR-330" devices who operate behind the CWMP device.

0.2.16  Minor bug in the ipv6 thingy, an ipv6 is a tuple of 8 integers.

0.2.15  Fixed the 204 header (end session) header in testcases.
        Introduced a configurable ipv6 listener.

0.2.14  Introduced the 204 header when ending a session. Thanks to softathome.

0.2.6   the cowboy ip is now configurable, so you can specify which ip to listen to.
        or even {0, 0, 0, 0, 0, 0, 0, 0} for all ipv6 and ipv4, for instance.
