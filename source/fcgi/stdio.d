module fcgi.stdio;

public import fcgi.app;
import std.format;
import std.traits;
import std.format : formattedWrite;


void writeln(S...)(S args)
{
    write(args, '\n');
}

void writefln(S...)(in char[] fmt, S args)
{
    writef(fmt, args);
    request.stdout.put('\n');
}

void putc(char c)
{
    request.stdout.put(c);
}

void writef(S...)(in char[] fmt, S args)
{
    formattedWrite(&request.stdout, fmt, args);
}

void write(S...)(S args)
{
    import std.traits : isBoolean, isIntegral, isAggregateType, isSomeString, isSomeChar;
    foreach (arg; args)
    {
        alias A = typeof(arg);
        static if (isAggregateType!A || is(A == enum))
        {
            formattedWrite(&request.stdout, "%s", arg);
        }
        else static if (isSomeString!A)
        {
            request.stdout.writeBlock(arg.ptr, arg.length * typeof(arg[0]).sizeof);
        }
        else static if (isIntegral!A)
        {
            import std.conv: toTextRange;
            toTextRange(arg, &request.stdout);
        }
        else static if (isBoolean!A)
        {
            arg ?
            request.stdout.writeBlock("true".ptr, 4):
            request.stdout.writeBlock("false".ptr, 5);
        }
        else static if (is(A == char))
        {
            request.stdout.put(arg);
        }
        else
        {
            std.format.formattedWrite(&request.stdout, "%s", arg);
        }
    }
}

void flush()
{
    request.stdout.flush();
}

size_t read(T)(T buf)
{
    return request.stdout.read(cast(ubyte*)buf.ptr, buf.length);
}


alias ThreadProc = void function(size_t n);

public import std.concurrency;



