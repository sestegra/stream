//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Tue, Jan 08, 2013 12:08:05 PM
// Author: tomyeh
part of stream;

/** The error handler. */
typedef void ErrorHandler(e);

/**
 * Stream server.
 */
abstract class StreamServer {
  factory StreamServer({Map<String, Function> urlMapping})
  => new _StreamServer(urlMapping: urlMapping);

  /** The home directory.
   */
  final Directory homeDir;

  /** The port. Default: 8080.
   */
  int port;
  /** The host. Default: "127.0.0.1".
   */
  String host;

  /** The timeout, in seconds, for sessions of this server.
   * Default: 1200 (unit: seconds)
   */
  int sessionTimeout;

  /** The error handler that is called when a connection error occur.
   */
  ErrorHandler onError;

  /** Indicates whether the server is running.
   */
  final bool isRunning;
  /** Starts the server
   *
   * If [serverSocket] is given (not null), it will be used ([host] and [port])
   * will be ignored. In additions, the socket won't be closed when the
   * server stops.
   */
  void run([ServerSocket socket]);
  /** Stops the server.
   */
  void stop();

  /** The logger for logging information.
   * The default level is `INFO`.
   */
  final Logger logger;
}

class _StreamServer implements StreamServer {
  final String version = "0.1.0";
  final HttpServer _server;
  String _host = "127.0.0.1";
  int _port = 8080;
  int _sessTimeout = 20 * 60; //20 minutes
  final Logger logger;
  Directory _homeDir;
  bool _running = false;

  _StreamServer({Map<String, Function> urlMapping, String homeDir}):
  _server = new HttpServer(), logger = new Logger("stream") {
    loggingConfigurer.configure(logger);
    _init();
    _initDir(homeDir);
    _initMapping(urlMapping);
  }
  void _init() {
    _server.onError = (e) {
      if (onError != null)
        onError(e);
    };
  }
  void _initDir(String homeDir) {
    var path;
    if (homeDir != null) {
      path = new Path(homeDir);
    } else {
      homeDir = new Options().script;
      path = homeDir != null ? new Path(homeDir).directoryPath: new Path("");
    }

    if (!path.isAbsolute)
      path = new Path.fromNative(new Directory.current().path).join(path);

    //look for webapp
    for (final orgpath = path;;) {
      final nm = path.filename;
      path = path.directoryPath;
      if (nm == "webapp")
        break; //found and we use its parent as homeDir
      final ps = path.toString();
      if (ps.isEmpty || ps == "/")
        throw new StreamException(
          "The application must be under the webapp directory, not ${orgpath.toNativePath()}");
    }

    _homeDir = new Directory.fromPath(path);
    if (!_homeDir.existsSync())
      throw new StreamException("$homeDir doesn't exist.");
  }
  void _initMapping(Map<String, Function> mapping) {

  }

  @override
  Directory get homeDir => _homeDir;

  @override
  int get port => _port;
  @override
  void set port(int port) {
    _assertIdle();
    _port = port;
  }
  @override
  String get host => _host;
  @override
  void set host(String host) {
    _assertIdle();
    _host = host;
  }
  @override
  int get sessionTimeout => _sessTimeout;
  @override
  void set sessionTimeout(int timeout) {
    _sessTimeout = _server.sessionTimeout = timeout;
  }

  @override
  ErrorHandler onError;

  @override
  bool get isRunning => _running;
  //@override
  void run([ServerSocket socket]) {
    _assertIdle();
    if (socket != null)
      _server.listenOn(socket);
    else
      _server.listen(host, port);

    logger.info("Rikulo Stream Server $version starting on "
      "${socket != null ? '$socket': '$host:$port'}\n"
      "Home: ${homeDir.path}");
  }
  //@override
  void stop() {
    _server.close();
  }
  void _assertIdle() {
    if (isRunning)
      throw new StateError("Already running");
    _server.close();
  }
}
