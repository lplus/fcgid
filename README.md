How to build
=================

* to build the library run:

```shell
$ dub build
```

* to build the example echo
```shell
$ dub build fcgid:echo 
```

* use spawn-fcgi to run example
```shell
spawn-fcgi -p[port] ./fcgid_echo
```

TODO:
-----------------
1. add thread example
2. full protocol implement
3. bugs
