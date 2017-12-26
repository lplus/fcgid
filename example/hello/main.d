import std.concurrency;
import fcgi.stdio;

void main() 
{
    init();
    while(accept)
    {
    	write("Content-Type: text/html; charset=UTF-8\r\n\r\n");
    	
    	writeln("<h1>Hello FastCGI </h1>\n");
    	
    	finish;
    }
}
