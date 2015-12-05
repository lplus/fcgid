module fcgi.app;
//import core.sys.posix.sys.socket;
//import core.sys.posix.unistd;
import std.socket;
import std.stdio;
import std.traits;

Request request;

void init()
{
	
	auto family = AddressFamily.INET;
	//stdout.close();
	stdout.open("c:\\Workspace\\xx", "w+");
	version(Posix)
	{
		import core.sys.posix.sys.socket;
		sockaddr_storage ss;
		socklen_t nameLen = ss.sizeof;
		if(-1 == getsockname(Protocol.listenfd, cast(sockaddr*)&ss, &nameLen)) {
			perror("getsockname");
		}
		if(ss.ss_family == AF_UNIX) {
			family = AddressFamily.UNIX;
			writeln("AF_UNIX");
		}
		request.listenSock = new Socket(cast(socket_t)0, family);
	}

	version(Windows)
	{
		import core.sys.windows.windows;
		HANDLE stdinHandle = GetStdHandle(STD_INPUT_HANDLE);
		request.listenSock = new Socket(cast(socket_t)stdinHandle, AddressFamily.INET);
		writeln("stdinHandle:", stdinHandle);
		stdout.flush();
	}
}

bool accept()
{
	writeln("begin accept");
	
	 if (request.ipcSockClosed) {
		synchronized {
			try {
				writeln("do accept");
				request.ipcSock = request.listenSock.accept();
				writeln("accept end");
			}
			catch(SocketAcceptException e)
			{
				writeln(e);
				return false;
			}
			request.ipcSockClosed = false;
		}
		writeln("ipcSock:", request.ipcSock);
		stdout.flush();
	 }
	else {
		writeln("handle:", request.ipcSock.handle);
		writeln("not accept");
		stdout.flush;
	}
    
	stdout.flush;
	request.stdin.fillBuffer();
	request.stdin.processProtocol;
	return true;
}

void finish()
{
	request.stdout.flush();
	request.stdin.buffer[] = 0;
	request.stdin.next = 0;
	request.stdin.bufferStop = 0;
	request.stdin.contentStop = 0;
	//.close(request.ipcfd);
	stdout.flush;
	if (request.keepConnection){
		writeln("not close");
		return;
	}
	writeln("close");
	request.ipcSock.close();
	request.ipcSockClosed = true;
}


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
	Socket ipcSock;
	bool ipcSockClosed = true;
	static Socket listenSock;

}

private:
enum bufferMaxLength = 8192;
struct InputStream
{
	size_t read(void* ptr, size_t length)
	{
		if (next == contentStop) {
			fillBuffer;
		}
		
		import std.algorithm.comparison:min;
		auto len = min(length, contentStop - next);
	    ptr[0 .. len] = buffer[next .. len + next];
		return len;
	}
	
	size_t read(void[] buf)
	{
	    return read(buf.ptr, buf.length);
	}

	char read()
	{
		if (next == contentStop) {
			fillBuffer;
		}

		return cast(char)buffer[next++];
	}
	
private:
	ubyte[bufferMaxLength] buffer;

	size_t	contentLength;
	ubyte	paddingLength;
	size_t	next;
	size_t	stop;
	size_t	contentStop;
	size_t	bufferStop;

	bool fillBuffer()
	{
		if (next == bufferStop) {
			auto readn= request.ipcSock.receive(buffer[next .. $]);
    		if (readn == Socket.ERROR) {
				writeln("ipcSock.receive ERROR");
				stdout.flush();
    		}
			if (readn == 0) {
				request.ipcSock.close();
				request.ipcSockClosed = true;
				return false;
			}
			bufferStop += readn;

			writeln("receive:", readn);
			stdout.flush();
		}
		
		writeln(buffer[0 .. 16]);
		writeln(buffer[16 .. 32]);
		writeln(buffer[0 .. 64]);
		//processProtocol();
		stdout.flush;
		return true;
	}
	
	void processProtocol()
	{
	    do {
	        // process Header
			if (next == contentStop) {
				fillBuffer;
			}
    		auto header = cast(Protocol.Header*)(buffer.ptr + next);
    		next += Protocol.Header.sizeof;
    		
    		request.requestId =	(header.requestIdB1 << 8)
    								+ header.requestIdB0;
    		contentLength =	(header.contentLengthB1 << 8)
    						+ header.contentLengthB0;
    					
			contentStop = next + contentLength;
			writeln("===============================");
			writeln("requestId:", request.requestId);
    		paddingLength = header.paddingLength;
			writeln("contentLength: ", contentLength);
			writeln("paddingLength: ", paddingLength);
			writeln(*header);
			stdout.flush();
            // process Body
            switch (header.type)
            {
                case Protocol.requestType.begin:
                    auto body_ = cast(Protocol.BeginRequestBody*)(buffer.ptr + next);
                    next += Protocol.BeginRequestBody.sizeof;
                    request.keepConnection = (body_.flags & Protocol.keepConnection);
                    request.role = (body_.roleB1 << 8) + body_.roleB0;
					if (request.role == Protocol.role.responder) {
						request.params["FCGI_ROLE"] = "RESPONDER".dup;
					}
					else if (request.role == Protocol.role.authorizer) {
						request.params["FCGI_ROLE"] = "AUTHORIZER".dup;
					}
					else if (request.role == Protocol.role.filter) {
						request.params["FCGI_ROLE"] = "FILTER".dup;
					}
					else {
						request.params["FCGI_ROLE"] = "UNKNOW".dup;
					}
					writeln("keepConnection:", request.keepConnection);
					writeln("role:", request.role);
                    writeln("Request Type: begin");
					writeln(*body_);
                    stdout.flush;
                    break;
                case Protocol.requestType.Params:
                    writeln("Request Type: Params");
                    // TODO: read params
                    size_t nameLen, valueLen;
                    auto begin = next;
                    while(next < contentStop) {
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
                        writeln(name, " #=# ", value);
						if (name == "CONTENT_LENGTH") {
							writeln("valueLen:", valueLen);
							writeln("value:", value);
							writeln("valueSize", value.length);
						}
                    }
                    next += header.paddingLength;
                    writeln("next::", next);
					stdout.flush;
                    return;                  
                case Protocol.requestType.Stdin:
                    writeln("Request Type: Stdin");
					stdout.flush;
                    return;
                case Protocol.requestType.End:
                    writeln("Request Type: End");
					stdout.flush;
                    return;
                default:
                    writeln("Request Type: Unknow", (cast(char*) header)[0 .. 80]);
					stdout.flush;
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
        header.type             = cast(ubyte) type;
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
	    auto paddingLength = alignLength - next;
		next = alignLength;
	    auto header = cast(Protocol.Header*)buffer.ptr;
	    makeHeader(
	        header, 
	        Protocol.requestType.Stdout, 
	        contentLength,
	        cast(ubyte)paddingLength
        );
	    
	    Protocol.Header endHeader;
	    makeHeader(
	        &endHeader, 
	        Protocol.requestType.End, 
	        Protocol.EndRequestBody.sizeof, 
	        cast(ubyte)0
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
        //core.sys.posix.unistd.write(request.ipcfd, buffer.ptr, alignLength);
		writeln(buffer[next - 16 .. next]);
		request.ipcSock.send(buffer[0 .. next]);
        buffer[] = 0;
        next = 8;
        begin = 8;
		stdout.flush;
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

