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

* nginx config
```shell
location / {
	include fastcgi_params;
	fastcgi_pass 127.0.0.1:9001;
}
```

* use spawn-fcgi to run example
```shell
spawn-fcgi -p9001 ./fcgid_echo
```


TODO:
-----------------
1. add thread example
2. full protocol implement
3. bugs
