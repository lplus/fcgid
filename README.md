How to build
=================

* to build the library run:

```shell
$ dub build
```

* to build the example echo
```shell
$ dub build fcgid:hello
$ dub build fcgid:echo 
```

* nginx config
```shell
location / {
	include fastcgi_params;
	fastcgi_pass 127.0.0.1:9001;
}
```

* use spawn-fcgi tu run example hello
```
spawn-fcgi -p9001 ./fcgid_hello
```

* use spawn-fcgi to run example multiple thread echo
```shell
spawn-fcgi -p9001 ./fcgid_echo
```

TODO:
-----------------
1. full protocol implement
2. bugs
