How to build
=================

1. to build the library run:<br/>
$ dub build

2. to build the example echo<br/>
$ dub build fcgid:echo 

3. use spawn-fcgi to run example<br/>
$ spawn-fcgi -p[port] ./fcgid_echo <br/>

TODO:
-----------------
1. add windows version support<br/>
2. add thread example
3. full protocol implement
3. show errors
