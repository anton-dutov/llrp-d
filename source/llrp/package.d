import std.stdio;
import std.bitmanip;
import std.algorithm: min;

unittest
{
    foreach(m; [
        cast(Msg) new GetSupportedVersionMsg(),
        cast(Msg) new GetSupportedVersionResponseMsg(new LLRPStatusParameter(StatusCode.M_Success, "TEST"), Msg.Version.v1_1),
        cast(Msg) new SetProtocolVersionMsg(Msg.Version.v1_1),
        cast(Msg) new GetReportMsg(),
        cast(Msg) new KeepaliveMsg(),
        cast(Msg) new KeepaliveAckMsg(),
        cast(Msg) new EnableEventsAndReportsMsg(),
        cast(Msg) new CloseConnectionMsg(),
    ])
    {
        writeln(m);
        writeln(m.pack);
    }
}

enum StatusCode
{
    M_Success              = 0,
    M_ParameterError       = 100,
    M_FieldError           = 101,
    M_UnexpectedParameter  = 102,
    M_MissingParameter     = 103,
    M_DuplicateParameter   = 104,
    M_OverflowParameter    = 105,
    M_OverflowField        = 106,
    M_UnknownParameter     = 107,
    M_UnknownField         = 108,
    M_UnsupportedMessage   = 109,
    M_UnsupportedVersion   = 110,
    M_UnsupportedParameter = 111,
    M_UnexpectedMessage    = 112,
    P_ParameterError       = 200,
    P_FieldError           = 201,
    P_UnexpectedParameter  = 202,
    P_MissingParameter     = 203,
    P_DuplicateParameter   = 204,
    P_OverflowParameter    = 205,
    P_OverflowField        = 206,
    P_UnknownParameter     = 207,
    P_UnknownField         = 208,
    P_UnsupportedParameter = 209,
    A_Invalid              = 300,
    A_OutOfRange           = 301,
    R_DeviceError          = 401,
}

enum AirProtocol : int
{
    Unspecified   = 0,
    EPCGlobalC1G2 = 1
}

struct UnpackResult
{
    Msg msg;
}

struct UnpackParamResult
{
    Parameter param;
}

class Msg
{
    enum minLength = 10;
    enum Version : ubyte
    {
        v1_0_1 = 1,
        v1_1   = 2,
    }

    enum Type : ushort
    {
        // Protocol version management
        GET_SUPPORTED_VERSION          = 46,
        GET_SUPPORTED_VERSION_RESPONSE = 56,
        SET_PROTOCOL_VERSION           = 47,
        SET_PROTOCOL_VERSION_RESPONSE  = 57,

        // Reader device capabilities
        GET_READER_CAPABILITIES          = 1,
        GET_READER_CAPABILITIES_RESPONSE = 11,

        //Reader device configuration
        GET_READER_CONFIG          = 2,
        GET_READER_CONFIG_RESPONSE = 12,
        SET_READER_CONFIG          = 3,
        SET_READER_CONFIG_RESPONSE = 13,
        CLOSE_CONNECTION           = 14,
        CLOSE_CONNECTION_RESPONSE  = 4,

        // Reader operations control
        ADD_ROSPEC              = 20,
        ADD_ROSPEC_RESPONSE     = 30,
        DELETE_ROSPEC           = 21,
        DELETE_ROSPEC_RESPONSE  = 31,
        START_ROSPEC            = 22,
        START_ROSPEC_RESPONSE   = 32,
        STOP_ROSPEC             = 23,
        STOP_ROSPEC_RESPONSE    = 33,
        ENABLE_ROSPEC           = 24,
        ENABLE_ROSPEC_RESPONSE  = 34,
        DISABLE_ROSPEC          = 25,
        DISABLE_ROSPEC_RESPONSE = 35,
        GET_ROSPECS             = 26,
        GET_ROSPECS_RESPONSE    = 36,

        //Access control
        ADD_ACCESSSPEC              = 40,
        ADD_ACCESSSPEC_RESPONSE     = 50,
        DELETE_ACCESSSPEC           = 41,
        DELETE_ACCESSSPEC_RESPONSE  = 51,
        ENABLE_ACCESSSPEC           = 42,
        ENABLE_ACCESSSPEC_RESPONSE  = 52,
        DISABLE_ACCESSSPEC          = 43,
        DISABLE_ACCESSSPEC_RESPONSE = 53,
        GET_ACCESSSPECS             = 44,
        GET_ACCESSSPECS_RESPONSE    = 54,
        CLIENT_REQUEST_OP           = 45,
        CLIENT_REQUEST_OP_RESPONSE  = 55,

        // Reports
        GET_REPORT                = 60,
        RO_ACCESS_REPORT          = 61,
        KEEPALIVE                 = 62,
        KEEPALIVE_ACK             = 72,
        READER_EVENT_NOTIFICATION = 63,
        ENABLE_EVENTS_AND_REPORTS = 64,

        // Errors
        ERROR_MESSAGE = 100,

        // Custom Extension
        CUSTOM_MESSAGE = 1023,
    }

    private
    {
        Version _ver;
        Type    _type;
        uint    _id;
    }

    @property Version ver() const   @safe
    {
        return _ver;
    }

    @property Type type() const   @safe
    {
        return _type;
    }

    @property uint id() const   @safe
    {
        return _id;
    }
    @property void id(uint i)   @safe
    {
        _id = i;
    }

    this(Type type, uint id = 0, Version ver = Version.v1_0_1)   @safe
    {
        _type = type;
        _id   = id;
        _ver  = ver;
    }


    final ubyte[] pack() const
    {
        ubyte[] ret;
        ushort  lead = (cast(ushort) (_ver & 0x07) << 10) | (_type & 0x3FF);
        auto    data = packData;

        ret ~= nativeToBigEndian(lead);
        ret ~= nativeToBigEndian(cast(uint) (data.length + minLength));
        ret ~= nativeToBigEndian(_id);
        ret ~= data;
        return ret;
    }

    protected ubyte[] packData() const
    {
        return [];
    }

    static uint lengthOf(in ubyte[] data)   @safe
    {
        if (data.length < minLength)
        {
            return 0;
        }
        return data[2 .. 6].bigEndianToNative!uint;
    }

    static UnpackResult unpack(in ubyte[] data)   @safe
    {
        UnpackResult ret;

        if (data.length < minLength)
        {
            return ret;
        }

        auto mLen = lengthOf(data);


        if (data.length != mLen)
        {
            return ret;
        }

        auto mLead = data[0 ..  2].bigEndianToNative!ushort;
        auto mId   = data[6 .. 10].bigEndianToNative!uint;

        auto mType = cast(Type) (mLead & 0x3FF);

        switch(mType)
        {
            case Type.GET_READER_CONFIG_RESPONSE:
                ret.msg = new GetReaderConfigResponseMsg(data[minLength .. $]);
                break;
            case Type.ERROR_MESSAGE:
                ret.msg = new ErrorMsg(data[minLength .. $]);
                break;
            default:
                ret.msg = new Msg(mType, mId);
                break;
        }

        ret.msg.id = mId;


        return ret;
    }
}

class GetSupportedVersionMsg : Msg
{
    this()
    {
        super(Type.GET_SUPPORTED_VERSION);
    }

    //override protected ubyte[] packData() const
    //{
        //return [0, 0];
    //}
}

class GetSupportedVersionResponseMsg : Msg
{
    private
    {
        LLRPStatusParameter _status;
        Version             _supportedVersion;
        Version             _currentVersion;
    }

    this(LLRPStatusParameter status, Version supportedVersion,  Version currentVersion = Version.v1_0_1)
    {
        super(Type.GET_SUPPORTED_VERSION);

        _status           = status;
        _supportedVersion = supportedVersion;
        _currentVersion   = currentVersion;
    }

    override protected ubyte[] packData() const
    {
        ubyte[] ret;
        ret ~= cast(ubyte) _currentVersion;
        ret ~= cast(ubyte) _supportedVersion;
        ret ~= _status.pack;
        return ret;
    }
}


class SetProtocolVersionMsg : Msg
{
    private
    {
        Version _protocolVersion;
    }

    this(Version protocolVersion)
    {
        super(Type.SET_PROTOCOL_VERSION);
        _protocolVersion = protocolVersion;
    }

    override protected ubyte[] packData() const
    {
        return [cast(ubyte) _protocolVersion & 0x07];
    }
}

class GetRospecsMsg : Msg
{
    this()
    {
        super(Type.GET_ROSPECS);
    }
}

class KeepaliveMsg : Msg
{
    this()
    {
        super(Type.KEEPALIVE);
    }
}

class KeepaliveAckMsg : Msg
{
    this()
    {
        super(Type.KEEPALIVE_ACK);
    }
}

class GetReportMsg : Msg
{
    this()
    {
        super(Type.GET_REPORT);
    }
}


class EnableEventsAndReportsMsg : Msg
{
    this()
    {
        super(Type.ENABLE_EVENTS_AND_REPORTS);
    }
}

class CloseConnectionMsg : Msg
{
    this()
    {
        super(Type.CLOSE_CONNECTION);
    }
}

class ErrorMsg : Msg
{
    private
    {
        LLRPStatusParameter _status;
    }

    private this(in ubyte[] data)   @safe
    {
        super(Type.ERROR_MESSAGE);
        _status = cast(LLRPStatusParameter) Parameter.unpack(data).param;
    }

    @property const(LLRPStatusParameter) status() const   @safe
    {
        return _status;
    }


    this()
    {
        super(Type.ERROR_MESSAGE);
    }
}


class GetReaderConfigMsg : Msg
{
    enum RequestedData : ubyte
    {
        All = 0,
        Identification = 1,
        AntennaProperties = 2,
        AntennaConfiguration = 3,
        ROReportSpec = 4,
        ReaderEventNotificationSpec = 5,
        AccessReportSpec = 6,
        LLRPConfigurationStateValue = 7,
        KeepaliveSpec = 8,
        GPIPortCurrentState = 9,
        GPOWriteData = 10,
        EventsAndReports = 11,
    }

    private
    {
        ushort          _anthenaId;
        RequestedData   _requestedData;
        ushort          _gpiPort;
        ushort          _gpoPort;
    }
    this()
    {
        super(Type.GET_READER_CONFIG);
    }


    override protected ubyte[] packData() const
    {
        ubyte[] ret;
        ret ~= nativeToBigEndian(_anthenaId);
        ret ~= nativeToBigEndian(cast(ubyte) _requestedData);
        ret ~= nativeToBigEndian(_gpiPort);
        ret ~= nativeToBigEndian(_gpoPort);
        return ret;
    }
}


class GetReaderConfigResponseMsg : Msg
{
    private
    {
        LLRPStatusParameter _status;
    }

    private this(in ubyte[] data)   @safe
    {
        super(Type.GET_READER_CONFIG_RESPONSE);
        _status = cast(LLRPStatusParameter) Parameter.unpack(data).param;


        import std.stdio;
        writeln(data);
    }

    @property const(LLRPStatusParameter) status() const   @safe
    {
        return _status;
    }

    this()
    {
        super(Type.GET_READER_CONFIG_RESPONSE);
    }
}

//=========================================
class Parameter
{
    enum minLength = 4;
    enum Type : ushort
    {
        AntennaID                = 1,
        FirstSeenTimestampUTC    = 2,
        FirstSeenTimestampUptime = 3,
        LastSeenTimestampUTC     = 4,
        LastSeenTimestampUptime  = 5,

        LLRPStatus     = 287,
        FieldError     = 288,
        ParameterError = 289,
        Custom         = 1023,
    }

    private
    {
        Type _type;
    }

    this(Type type)   @safe
    {
        _type = type;
    }

    final ubyte[] pack() const
    {
        ubyte[] ret;
        ushort  lead = (_type & 0x3FF);
        auto    data = packData;

        ret ~= nativeToBigEndian(lead);
        ret ~= nativeToBigEndian(cast(ushort) data.length);
        ret ~= data;
        return ret;
    }

    protected ubyte[] packData() const
    {
        return [];
    }

    static ushort lengthOf(in ubyte[] data)   @safe
    {
        if (data.length < minLength)
        {
            return 0;
        }
        return data[2 .. 4].bigEndianToNative!ushort;
    }

    static UnpackParamResult unpack(in ubyte[] data)   @safe
    {
        UnpackParamResult ret;

        if (data.length < minLength)
        {
            return ret;
        }

        auto pLen = lengthOf(data);


        if (data.length != pLen)
        {
            return ret;
        }

        auto pLead = data[0 ..  2].bigEndianToNative!ushort;
        //auto mId   = data[6 .. 10].bigEndianToNative!uint;

        auto pType = cast(Type) (pLead & 0x3FF);

        switch(pType)
        {
            case Type.LLRPStatus:
                ret.param = new LLRPStatusParameter(data[minLength .. $]);
                break;
            default:
                ret.param = new Parameter(pType);
                break;
        }

        //ret.msg.id = mId;


        return ret;
    }
}


class  FieldErrorParameter : Parameter
{
    private
    {
        StatusCode _code;
        ushort     _field;
    }

    this(StatusCode code, ushort field)
    {
        super(Type.FieldError);

        _code  = code;
        _field = field;
    }

    override protected ubyte[] packData() const
    {
        ubyte[] ret;
        ret ~= nativeToBigEndian(cast(ushort) _field);
        ret ~= nativeToBigEndian(cast(ushort) _code);
        return ret;
    }
}

class  ParameterErrorParameter : Parameter
{
    private
    {
        StatusCode              _code;
        Type                    _type;
        FieldErrorParameter     _fieldError;
        ParameterErrorParameter _paramError;
    }

    this(StatusCode code, Type type)
    {
        super(Type.ParameterError);

        _code = code;
        _type = type;
    }

    override protected ubyte[] packData() const
    {
        ubyte[] ret;
        ret ~= nativeToBigEndian(cast(ushort) _type);
        ret ~= nativeToBigEndian(cast(ushort) _code);

        if (_fieldError !is null)
        {
            ret ~= _fieldError.pack;
        }

        if (_paramError !is null)
        {
            ret ~= _paramError.pack;
        }

        return ret;
    }
}

class LLRPStatusParameter : Parameter
{
    private
    {
        StatusCode              _code;
        string                  _description;
        FieldErrorParameter     _fieldError;
        ParameterErrorParameter _paramError;
    }

    @property StatusCode code() const   @safe
    {
        return _code;
    }

    @property string description() const   @safe
    {
        return _description;
    }

    private this(in ubyte[] data)   @trusted
    {
        super(Type.LLRPStatus);
        auto l = data[2 .. 4].bigEndianToNative!ushort;
        _code        = cast(StatusCode) data[0 .. 2].bigEndianToNative!ushort;
        _description = cast(string) data[4 .. 4 + l].dup;
    }

    this(StatusCode code, string description)
    {
        super(Type.LLRPStatus);

        _code        = code;
        _description = description;
    }

    override protected ubyte[] packData() const
    {
        ubyte[] ret;
        ret ~= nativeToBigEndian(cast(ushort) _code);
        ret ~= nativeToBigEndian(cast(ushort) _description.length);
        ret ~= cast(ubyte[]) _description.dup[0 .. min($, 0xFFFF)];

        if (_fieldError !is null)
        {
            ret ~= _fieldError.pack;
        }

        if (_paramError !is null)
        {
            ret ~= _paramError.pack;
        }

        return ret;
    }
}
