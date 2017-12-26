/**
  * multiple thread example
  */
import std.concurrency;
import fcgi.stdio;

struct A
{
    int a;
    int x;
    char[] str = ['h', 'e', 'l', 'l', 'o'];
    
    struct B
    {
        bool b = true;
        bool bf = false;
        uint ui = 123;
        string str = "a string";
    }
}

void threadMain(ubyte n)
{

	init();
    while(accept)
    {
		writeln("after accept");
    	write("Content-Type: text/html; charset=UTF-8\r\n\r\n");

		string x = `sdf
		aaa`;
    	
    	`<html>
    	<head> 
    	<title>Title: Simple FastCGI Loop</title>
    	</head>
    	<body>
    	<h1>FastCGI in D</h1>
    	<h2>多线程例子</h2>`
		.write;
    	
        writeln("<pre>");
        writefln("<B>线程号:%s</B>", n);
		writeln("RequestID:", request.requestId);
		writeln("<hr>");

		writeln("遍历参数:");
    	foreach(name, value; request.params) {
    	    writeln(name ~" : " ~ value);
    	}
		writeln("<hr>");
    	
		writeln("其它测试");
    	writeln("test writeln");
    	writef("the number is %d %s",  100, ".");
    	writeln(true);
    	A a = {12, 999};
        writeln(a);
        
        writefln("wstring %s", "是要工"w);
    	writeln("xxxxxxxxxx");
        writeln("</pre>");
    	`</body>
    	</html>`
    	.write;
		writeln("<hr>");
    	
    	finish;
    }
}

void main() 
{
    for (ubyte i=0; i<8; i++) {
        spawn(&threadMain, i);
    }
}
