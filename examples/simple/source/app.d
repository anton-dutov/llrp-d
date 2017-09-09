//import eventcore.core;
//import eventcore.socket;
import std.stdio : writefln;
import core.stdc.signal;
import core.sys.posix.signal : SIGHUP, SIGUSR1, SIGUSR2;
import core.time : Duration, msecs;
import std.socket : Address, InternetAddress;

import vibe.core.net;

import llrp;

bool s_done;


struct LLRPLink
{
    public
    {
        string         _id;
        bool           _isAttached;
        UnpackResult   _result;
        TCPConnection  _link;
    }

    @disable this();

    this(in string host, ushort port, in string id = "")
    {
        _id = id;

        _link = connectTCP(host, port);
        _link.tcpNoDelay = true;
        //auto addr = cast(Address) new InternetAddress(host, port);

        //_fd = eventDriver.sockets.connectStream(addr, null,
        //    (fd, status) @safe nothrow {
        //    if (fd != StreamSocketFD.invalid) eventDriver.sockets.addRef(fd);
        //    _isAttached = status == ConnectStatus.connected;
        //    if (fd != StreamSocketFD.invalid) eventDriver.sockets.releaseRef(fd);
        //});
        //eventDriver.sockets.addRef(_fd);
    }

    ~this()
    {
        //if (_fd != StreamSocketFD.invalid)
        //{
        //    eventDriver.sockets.releaseRef(_fd);
        //}
    }

    bool tryUpgrade()
    {
        send(new GetSupportedVersionMsg);
        waitNext();

        return _result.msg.type == Msg.Type.GET_SUPPORTED_VERSION_RESPONSE;
    }

    void showError()
    {
        if (auto e = cast(ErrorMsg) _result.msg)
        {
            writefln("CODE: %s", e.status.code);
            writefln("NOTE: %s", e.status.description);
        }
    }

    void waitNext()
    {
        ubyte[] tmp;
        tmp.length = Msg.minLength;

        ubyte[] msg;


        _link.read(tmp[]);

        msg ~= tmp.dup;

        tmp.length = Msg.lengthOf(tmp) - Msg.minLength;

        _link.read(tmp[]);

        msg ~= tmp.dup;

        _result = Msg.unpack(msg);
        writefln("   [%12s] %-30s %s", _result.msg.id, _result.msg.type, msg);
    }

    void send(Msg msg)
    {
        msg.id = _result.msg.id + 1;
        auto packed = msg.pack;
        _link.write(msg.pack);
        writefln(">> [%12s] %-30s %s", msg.id, msg.type, packed);
     }
}

void main()
{
    auto link = LLRPLink("192.168.1.1", 5084);
    writefln("Attached ",link._link.connected);
    link.waitNext();

    link.tryUpgrade();
    link.showError();


    link.send(new GetReaderConfigMsg);
    link.waitNext();

    if (auto c = cast(GetReaderConfigResponseMsg) link._result.msg)
    {
        //writefln("CODE: %s", c.status.code);
        //writefln("NOTE: %s", c.status.description);
    }

    //int cnt = 3;
    //while(--cnt > 0)
    //{
        //link.send(new GetSupportedVersionMsg);
        //link.waitNext();


    //}
}
