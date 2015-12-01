module fcgi.app;
import core.sys.posix.sys.socket;
import core.sys.posix.unistd;
import core.stdc.stdio;

import std.stdio;
import std.traits;
import std.range.primitives;

Request request;

bool accept()
{
    synchronized {
	    request.ipcfd = core.sys.posix.sys.socket.accept(Protocol.listenfd, null, null);
		if (request.ipcfd < 0) {
			return false;
		}
    }

	request.stdin.fillBuffer();
	return true;
}

void finish()
{
	request.stdout.flush();
	request.stdin.buffer[] = 0;
	request.stdin.next = 0;
	request.stdin.stop = 0;
	.close(request.ipcfd);
}

private:

struct Request
{
	InputStream stdin;
	auto stdout = OutputStream(bufferMaxLength);
	auto stderr = OutputStream(128);
    char[][string] params;
	int requestId;

	private:
	ubyte keepConnection;
	int role;
	int ipcfd = 0;
}

enum bufferMaxLength = 8192;
struct InputStream
{
	size_t read(void* ptr, size_t length)
	{
	    ptr[0 .. length] = buffer[next .. length];
		return 0;
	}
	
	size_t read(void[] buf)
	{
	    return read(buf.ptr, buf.length);
	}
	
private:
	ubyte[bufferMaxLength] buffer;

	size_t	contentLength;
	ubyte	paddingLength;
	size_t	next;
	size_t	stop;

	bool fillBuffer()
	{
		if (next == stop) {
			stop = core.sys.posix.unistd.read(request.ipcfd, buffer.ptr, buffer.length);
    		if (stop == -1) {
    			perror("fillBuffer: .read");
    		}
		}
		
		processProtocol();
		return true;
	}

	void processProtocol()
	{
	    do {
	        bool continue_ = false;
	        // process Header
    		auto header = cast(Protocol.Header*)(buffer.ptr + next);
    		next += header.sizeof;
    		
    		int requestId;
    		request.requestId =	(header.requestIdB1 << 8)
    								+ header.requestIdB0;
    		contentLength =	(header.contentLengthB1 << 8)
    						+ header.contentLengthB0;
    						
    		paddingLength = header.paddingLength;
			writeln("contentLength: ", contentLength);
			writeln("paddingLength: ", paddingLength);
			writeln("===============================");
    
            // process Body
            switch (header.type)
            {
                case Protocol.requestType.begin:
                    auto body_ = cast(Protocol.BeginRequestBody*)(buffer.ptr + next);
                    next += body_.sizeof;
                    request.keepConnection = (body_.flags & Protocol.keepConnection);
                    request.role = (body_.roleB1 << 8) + body_.roleB0;
                    writeln("Request Type: begin");
                    
                    break;
                case Protocol.requestType.Params:
                    writeln("Request Type: Params");
                    // TODO: read params
                    size_t nameLen, valueLen;
                    auto begin = next;
                    while(next - begin < contentLength) {
                        nameLen = ((buffer[next] & 0x80) != 0) ?
                            ((buffer[next++] & 0x7f) << 24) 
                            + (buffer[next++] << 16) 
                            + (buffer[next++] << 8) 
                            + buffer[next++]
                            : buffer[next++];
                            
                        valueLen = ((buffer[next] & 0x80) != 0)?
                            ((valueLen & 0x7f) << 24) 
                            + (buffer[next++] << 16)
                            + (buffer[next++] << 8)
                            + buffer[next++]
                            :buffer[next++];
                            
                        auto name = cast(string) buffer[next .. next+ nameLen].idup;
                        auto value = cast(char[])buffer[next + nameLen .. next + nameLen + valueLen];
                        request.params[name] = value; 
                        next += nameLen + valueLen;
                        writeln(name, " : ", value);
                    }
                    next += header.paddingLength;
                    writeln("next::", next);
                    break;                    
                case Protocol.requestType.Stdin:
                    writeln("Request Type: Stdin");
                    return;
                case Protocol.requestType.End:
                    writeln("Request Type: End");
                    return;
                default:
                    writeln("Request Type: Unknow", (cast(char*) header)[0 .. 80]);
                    return;
                
            }
            
		} while(true);

	}



}

struct OutputStream
{
	
    
    this(size_t bufferLength = bufferMaxLength)
    {
        buffer = new ubyte[bufferLength];
    }
    
	size_t writeBlock(const void* ptr, size_t length)
	{
	    auto p = cast(ubyte*) ptr;
	    buffer[next .. next + length] = p[0 .. length];
	    next += length;
		return length;
	}
	
	size_t write(ubyte[] buff)
	{
	    return this.writeBlock(buff.ptr, buff.length);
	}
	
	void write(ubyte b)
	{
	    buffer[next ++] = b;
	}
	
	size_t write(in char[] str)
	{
	    return this.writeBlock(str.ptr, str.length);
	}

    void put(A)(A writeme)
        if (is(ElementType!A : const(dchar)) &&
        isInputRange!A &&
        !isInfinite!A)
    {
        alias C = ElementEncodingType!A;
        writeBlock(cast(ubyte*)A.ptr, A.length * C.sizeof);
    }
    
    void put(char c)
    {
        buffer[next ++] = cast(ubyte)c;
    }
	
	size_t align8(size_t n) {
        return (n + 7) & (size_t.max - 7);
    }
	
	void makeHeader(Protocol.Header* header, ubyte type, size_t contentLength, ubyte paddingLength)
	{
	    
	    header.version_ = Protocol.version1;
        header.type             = cast(ubyte) Protocol.requestType.Stdout;
        header.requestIdB1      = cast(ubyte) ((request.requestId     >> 8) & 0xff);
        header.requestIdB0      = cast(ubyte) ((request.requestId         ) & 0xff);
        header.contentLengthB1  = cast(ubyte) ((contentLength >> 8) & 0xff);
        header.contentLengthB0  = cast(ubyte) ((contentLength     ) & 0xff);
        header.paddingLength    = paddingLength;
        header.reserved         =  0;
	}
	
	void flush()
	{
	    auto contentLength = (next - 8);
	    auto alignLength = align8(next);
	    next = alignLength;
	    auto header = cast(Protocol.Header*)buffer.ptr;
	    makeHeader(
	        header, 
	        Protocol.requestType.Stdout, 
	        contentLength,
	        cast(ubyte)(alignLength - contentLength)
        );
	    
	    Protocol.Header endHeader;
	    makeHeader(
	        &endHeader, 
	        Protocol.requestType.End, 
	        Protocol.EndRequestBody.sizeof, 
	        cast(ubyte)(alignLength - contentLength)
        );
	    
        Protocol.EndRequestBody endBody;

        endBody.protocolStatus = 0;
        endBody.appStatusB3 = 0;
        endBody.appStatusB2 = 0;
        endBody.appStatusB1 = 0;
        endBody.appStatusB0 = 0;
        
        next = alignLength;
	    writeBlock(cast(ubyte*)&endHeader, endHeader.sizeof);
	    writeBlock(cast(ubyte*)&endBody, endBody.sizeof);
	    writeln(buffer[0 .. 8]);
	    writeln(cast(char[]) buffer[8 .. next]);
        core.sys.posix.unistd.write(request.ipcfd, buffer.ptr, alignLength);
        buffer[] = 0;
        next = 8;
        begin = 8;
	}
	
	void setStdoutHeader();
private:
	ubyte[] buffer;

    size_t begin = 8;
    size_t next = 8;
}

struct Protocol
{
	enum listenfd = 0;

	enum nullRequestId = 0;
	
	enum version1 = 1;
	
	enum keepConnection = 1;

	enum role {
		responder	= 1,
		authorizer	= 2,
		filter 		= 3,
	}

	enum error {
		unsupportedVersion = -2
	}

	enum requestType {
		begin     = 1,
		Abort     = 2,
		End       = 3,
		Params    = 4,
		Stdin     = 5,
		Stdout    = 6,
		Stderr    = 7,
		Data      = 8,
		GetValues = 9,
		GetValuesResult = 10,
		UnknownType     = 11
	}

	struct Header
	{
    	ubyte version_;
    	ubyte type;
    	ubyte requestIdB1;
    	ubyte requestIdB0;
    	ubyte contentLengthB1;
    	ubyte contentLengthB0;
    	ubyte paddingLength;
    	ubyte reserved;
	}

	struct BeginRequestBody
	{
		ubyte roleB1;
		ubyte roleB0;
		ubyte flags;
		ubyte[5] reserved;
	}

	struct BeginRequestRecord
	{
		Header header;
		BeginRequestBody body_;
	}
	
	struct EndRequestBody
	{
    	ubyte appStatusB3;
    	ubyte appStatusB2;
    	ubyte appStatusB1;
    	ubyte appStatusB0;
    	ubyte protocolStatus;
    	ubyte[3] reserved;
	}

	struct EndRequestRecord
	{
		Header header;
		EndRequestBody body_;
	}

	struct UnknownTypeBody
	{
		ubyte type;
		ubyte[7] reserved;
	}

	struct UnknownTypeRecord
	{
		Header header;
		UnknownTypeBody body_;
	}
}



