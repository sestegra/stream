//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
//History: Mon, Jan 14, 2013  4:56:56 PM
// Author: tomyeh
part of stream_rspc;

/**
 * The RSP compiler
 */
class Compiler {
  final String source;
  final String sourceName;
  final IOSink destination;
  final String destinationName;
  final Encoding encoding;
  final bool verbose;
  //the closure's partOf, import, name, args...
  String _partOf, _import, _name, _args, _desc, _contentType;
  final List<_TagContext> _tagCtxs = [];
  _TagContext _current;
  //The position, length and _line of the source
  int _pos = 0, _len, _line = 1;
  //Look-ahead tokens
  final List _lookAhead = [];
  final List<_IncInfo> _incs = []; //included
  final List<_QuedTag> _quedTags = []; //queued tags (before _start is called)
  String _extra = ""; //extra whitespaces
  int _nextVar = 0; //used to implement TagContext.nextVar()

  Compiler(this.source, this.destination, {
      this.sourceName, this.destinationName, this.encoding:Encoding.UTF_8, this.verbose: false}) {
    _tagCtxs.add(_current = new _TagContext.root(this, destination));
    _len = source.length;
  }

  ///Compiles the given source into Dart code. Notice: it can be called only once.
  ///To compile the second time, you have to instantiate another [Compiler].
  void compile() {
    _writeln("//Auto-generated by RSP Compiler");
    if (sourceName != null)
      _writeln("//Source: ${sourceName}");

    bool pgFound = false, started = false;
    int prevln = 1;
    for (var token; (token = _nextToken()) != null; prevln = _line) {
      if (_current.args != null && token is! VarTag && token is! _Closing
      && (token is! String || !token.trim().isEmpty))
        _error("Only the var tag is allowed inside the ${_current.tag.name} tag, not $token");

      if (token is String) {
        String text = token;
        if (!started) {
          if (text.trim().isEmpty)
            continue; //skip it
          started = true;
          _start(prevln); //use previous line number since it could be multiple lines
        }
        _outText(text, prevln);
      } else if (token is _Expr) {
        if (!started) {
          started = true;
          _start();
        }
        _outExpr();
      } else if (token is PageTag) {
        if (pgFound)
          _error("Only one page tag is allowed", _line);
        if (started)
          _error("The page tag must be in front of any non-empty content", _line);
        pgFound = true;

        push(token);
        token.begin(_current, _tagData());
        token.end(_current);
        pop();
      } else if (token is DartTag) {
        if (!started) {
          _quedTags.add(new _QuedTag(token, _dartData()));
          continue;
        }

        push(token);
        token.begin(_current, _dartData());
        token.end(_current);
        pop();
      } else if (token is Tag) {
        if (!started) {
          if (token is HeaderTag) {
          //note: token.hasClosing must be false
            _quedTags.add(new _QuedTag(token, _tagData(tag: token)));
            continue;
          }
          started = true;
          _start();
        }

        push(token);
        token.begin(_current, _tagData(tag: token));
        if (!token.hasClosing) {
          token.end(_current);
          pop();
        }
      } else if (token is _Closing) {
        final _Closing closing = token;
        if (_current.tag == null || _current.tag.name != closing.name)
          _error("Unexpected [/${closing.name}] (no beginning tag found)", _line);
        _current.tag.end(_current);
        pop();
      } else {
        _error("Unknown token, $token", _line);
      }
    }

    if (started) {
      if (_tagCtxs.length > 1) {
        final sb = new StringBuffer();
        for (int i = _tagCtxs.length; --i >= 1;) {
          if (!sb.isEmpty) sb.write(', ');
          sb..write(_tagCtxs[i].tag)..write(' at line ')..write(_tagCtxs[i].line);
        }
        _error("Unclosed tag(s): $sb");
      }
      _writeln("\n$_extra  return \$nnf();");
      while (!_incs.isEmpty) {
        _extra = _extra.substring(2);
        _writeln("$_extra  ${_incs.removeLast().invocation} //end-of-include");
      }
      _writeln("}");
    }
  }
  void _start([int line]) {
    if (line == null) line = _line;
    if (_name == null) {
      if (sourceName == null || sourceName.isEmpty)
        _error("The page tag with the name attribute is required", line);

      _name = new Path(sourceName).filename;
      var i = _name.indexOf('.');
      _name = StringUtil.camelize(i < 0 ? _name: _name.substring(0, i));

      for (i = _name.length; --i >= 0;) { //check if _name is legal
        final cc = _name[i];
        if (!StringUtil.isChar(cc, upper:true, lower: true, digit: true)
            && cc != '\$' && cc != '_')
          _error("Unable to generate a legal function name from $sourceName. "
            "Please specify the name with the page tag.", line);
      }
    }

    if (verbose) _info("Generate $_name from line $line");

    if (_desc == null)
      _desc = "Template, $_name, for rendering the view.";

    final ctypeSpecified = _contentType != null;
    if (!ctypeSpecified && sourceName != null) {
      final i = sourceName.lastIndexOf('.');
      if (i >= 0) {
        final ct = contentTypes[sourceName.substring(i + 1)];
        if (ct != null)
          _contentType = ct.toString();
      }
    }

    final imports = new LinkedHashSet.from(["dart:async", "dart:io", "package:stream/stream.dart"]);
    if (_import != null)
      for (String imp in _import.split(',')) {
        imp = imp.trim();
        if (!imp.isEmpty)
          imports.add(imp);
      }

    if (_partOf == null || _partOf.isEmpty) { //independent library
      var lib = new Path(sourceName).filename;
      var i = lib.lastIndexOf('.'); //remove only one extension
      if (i >= 0) lib = lib.substring(0, i);

      final sb = new StringBuffer(), len = lib.length;
      for (i = 0; i < len; ++i) {
        final cc = lib[i];
        sb.write(StringUtil.isChar(cc, upper:true, lower: true, digit: true)
            || cc == '\$' ? cc: '_');
      }
      _writeln("library $sb;\n");

      for (final impt in imports)
        _writeln("import ${_toImport(impt)};");
    } else if (_partOf.endsWith(".dart")) { //needs to maintain the given dart file
      _writeln("part of ${_mergePartOf(imports)};");
    } else {
      if (_import != null && !_import.isEmpty)
        _warning("The import attribute is ignored since the part-of attribute is given");
      _writeln("part of $_partOf;");
    }

    _current.indent();
    _write("\n/** $_desc */\nFuture $_name(HttpConnect connect");
    if (_args != null)
      _write(", {$_args}");
    _writeln(") { //#$line\n"
      "  var _cs_ = new List<HttpConnect>(), request = connect.request, response = connect.response;\n");

    if (_contentType != null) {
      if (!ctypeSpecified) //if not specified, it is set only if not included
        _write('  if (!connect.isIncluded)\n  ');
      _writeln('  response.headers.contentType = new ContentType.fromString('
        '${toEL(_contentType, direct: false)});');
    }

    //generated the tags found before _start() is called.
    for (final ti in _quedTags) {
      push(ti.tag);
      ti.tag.begin(_current, ti.data);
      ti.tag.end(_current);
      pop();
    }
    _quedTags.clear();
  }

  ///Sets the page information.
  void setPage(String partOf, String imports, String name, String description, String args,
      String contentType, [int line]) {
    _partOf = partOf;
    _noEL(partOf, "the partOf attribute", line);
    _import = imports;
    _noEL(_import, "the import attribute", line);
    _name = name;
    _noEL(name, "the name attribute", line);
    _desc = description;
    _noEL(description, "the description attribute", line);
    _args = args;
    _noEL(args, "the args attribute", line);
    _contentType = contentType;
  }

  ///Include the given URI.
  void includeUri(String uri, [Map args, int line]) {
    _checkInclude(line);
    if (args != null && !args.isEmpty)
      _error("Not supported: include URI with arguments", line); //TODO: handle arguments
    if (verbose) _info("Include $uri", line);

    _writeln('\n${_current.pre}return connect.include('
      '${toEL(uri, direct: false)}).then((_) { //#$line');
    _extra = "  $_extra";
    _incs.add(new _IncInfo("});"));
  }
  ///Include the output of the given renderer
  void include(String method, [Map args, int line]) {
    _checkInclude(line);
    if (verbose) _info("Include $method", line);

    _write("\n${_current.pre}return \$nnf($method(new HttpConnect.chain(connect)");
    _outArgs(args);
    _writeln(")).then((_) { //include#$line");
    _extra = "  $_extra";
    _incs.add(new _IncInfo("});"));
  }
  ///Check if the include tag is allowed.
  ///It can be not put inside while/for/if...
  void _checkInclude(int line) {
    for (TagContext tc = _current; (tc = tc.parent) != null; ) {
      final tag = tc.tag;
      if (tag != null && tag is! IncludeTag && tag is! VarTag) {
        final pline = _tagCtxs[_tagCtxs.length - 2].line;
        _error("The include tag can't be under the [${tag.name}] tag (at ${pline})."
          "Try to split into multiple files.", line);
      }
    }
  }

  ///Forward to the given URI.
  void forwardUri(String uri, [Map args, int line]) {
    if (args != null && !args.isEmpty)
      _error("Not supported: forward URI with arguments"); //TODO: handle arguments
    if (verbose) _info("Forward $uri", line);

    _writeln("\n${_current.pre}return connect.forward("
      "${toEL(uri, direct: false)}); //#${line}");
  }
  //Forward to the given renderer
  void forward(String method, [Map args, int line]) {
    if (verbose) _info("Forward $method", line);

    _write("\n${_current.pre}return \$nnf(${method}(connect");
    _outArgs(args);
    _writeln(")); //forward#${line}");
  }
  void _outArgs(Map args) {
    if (args != null)
      for (final arg in args.keys) {
        _write(", ");
        _write(arg);
        _write(": ");
        _write(toEL(args[arg]));
      }
  }

  //Tokenizer//
  _nextToken() {
    if (!_lookAhead.isEmpty)
      return _lookAhead.removeLast();

    final sb = new StringBuffer();
    final token = _specialToken(sb);
    if (token is _Closing)
      _skipFollowingSpaces();

    final text = _rmSpacesBeforeTag(sb.toString(), token);
    if (text.isEmpty)
      return token;

    if (token != null)
      _lookAhead.add(token);
    return text;
  }
  _specialToken(StringBuffer sb) {
    while (_pos < _len) {
      final cc = source[_pos];
      if (cc == '[') {
        final j = _pos + 1;
        if (j < _len) {
          final c2 = source[j];
          if (c2 == '=') { //[=exprssion]
            _pos = j + 1;
            return new _Expr();
          } else if (c2 == ':' || c2 == '/') { //[:beginning-tag] or [/closing-tag]
            int k = j + 1;
            if (k < _len && StringUtil.isChar(source[k], lower:true)) {
              int m = _skipId(k);
              final tagnm = source.substring(k, m);
              final tag = tags[tagnm];
              if (tag != null) {
                if (c2 == ':') { //beginning of tag
                  _pos = m;
                  return tag;
                } else if (m < _len && source[m] == ']') { //ending of tag found
                  if (!tag.hasClosing)
                    _error("[/$tagnm] not allowed. It doesn't need the closing tag.", _line);
                  _pos = m + 1;
                  return new _Closing(tagnm);
                }
              }
            }
            //fall through
          } else if (c2 == '!') { //[!-- comment --]
            if (j + 2 < _len && source[j + 1] == '-' && source[j + 2] == '-') {
              _pos = _skipUntil("--]", j + 3) + 3;
              continue;
            }
          } else if (StringUtil.isChar(c2, lower:true)) { //[beginning-tag]
          //deprecated (TODO: remove later)
            int k = _skipId(j);
            final tn = source.substring(j, k), tag = tags[tn];
            if (tag != null) //tag found
              _warning("[$tn] is deprecated and ignored. Please use [:$tn] instead.", _line);
            //fall through
          }
        }
      } else if (cc == '\\') { //escape
        final j = _pos + 1;
        if (j < _len && source[j] == '[') {
          sb.write('['); //\[ => [
          _pos += 2;
          continue;
        }
      } else if (cc == '\n') {
        _line++;
      }
      sb.write(cc);
      ++_pos;
    } //for each cc
    return null;
  }
  ///(Optional but for better output) Skips the following whitespaces untile linefeed
  void _skipFollowingSpaces() {
    for (int i = _pos; i < _len; ++i) {
      final cc = source[i];
      if (cc == '\n') {
        ++_line;
        _pos = i + 1; //skip white spaces until and including linefeed
        return;
      }
      if (cc != ' ' && cc != '\t')
        break; //don't skip anything
    }
  }
  ///(Optional but for better output) Removes the whitspaces before the given token,
  ///if it is a tag. Notice: [text] is in front of [token]
  String _rmSpacesBeforeTag(String text, token) {
    if (token is! Tag && token is! _Closing)
      return text;

    for (int i = text.length; --i >= 0;) {
      final cc = text[i];
      if (cc == '\n')
        return text.substring(0, i + 1); //remove tailing spaces (excluding \n)
      if (cc != ' ' && cc != '\t')
        return text; //don't skip anything
    }
    return "";
  }
  int _skipUntil(String until, int from) {
    final line = _line;
    final nUtil = until.length;
    String first = until[0];
    for (; from < _len; ++from) {
      final cc = source[from];
      if (cc == '\n') {
        _line++;
      } else if (cc == '\\' && from + 1 < _len) { //escape
        if (source[++from] == '\n')
          _line++;
      } else {
        if (cc == first) {
          if (from + nUtil > _len)
            break;
          for (int n = nUtil;;) {
            if (--n < 1) //matched
              return from;

            if (source[from + n] != until[n])
              break; //continue to next character
          }
        }
      }
    }
    _error("Expect '$until'", line);
  }
  int _skipId(int from) {
    for (; from < _len; ++from) {
      final cc = source[from];
      if (!StringUtil.isChar(cc, lower:true, upper:true))
        break;
    }
    return from;
  }
  ///Skip arguments (of a tag)
  int _skipTagArgs(int from, bool ignoreSlash) {
    final line = _line;
    String sep;
    int nbkt = 0;
    for (; from < _len; ++from) {
      final cc = source[from];
      if (cc == '\n') {
        _line++;
      } else if (cc == '\\' && from + 1 < _len) {
        if (source[++from] == '\n')
          _line++;
      } else if (sep == null) {
        if (cc == '"' || cc == "'") {
          sep = cc;
        } else if (nbkt == 0 && ((!ignoreSlash && cc == '/') || cc == ']')) {
          return from;
        } else if (cc == '[') {
          ++nbkt;
        } else if (cc == ']') {
          --nbkt;
        }
      } else if (cc == sep) {
        sep = null;
      }
    }
    _error("Expect ']'", line);
  }
  ///Note: [tag] is required if `tag.hasClosing` is 
  String _tagData({Tag tag, skipFollowingSpaces: true, ignoreSlash: false}) {
    int k = _skipTagArgs(_pos, ignoreSlash);
    final data = source.substring(_pos, k).trim();
    _pos = k + 1;
    if (source[k] == '/') {
      if (tag != null && tag.hasClosing)
        _lookAhead.add(new _Closing(tag.name));

      _skipFollowingSpaces();
      if (_pos >= _len || source[_pos] != ']')
        _error("Expect ']'");
      ++_pos;
    }
    if (skipFollowingSpaces)
      _skipFollowingSpaces();
    return data;
  }
  String _dartData() {
    String data = _tagData(tag: tags["dart"]);
    if (!data.isEmpty)
      _warning("The dart tag has no attribute", _line);

    if (!_lookAhead.isEmpty) { //we have to check if it is [dart/]
      final token = _nextToken();
      if (token is _Closing && token.name == "dart")
        return ""; //[dart/]
      _lookAhead.add(token); //add back
    }

    int k = _skipUntil("[/dart]", _pos);
    data = source.substring(_pos, k).trim();
    _pos = k + 7;
    return data;
  }

  //Utilities//
  void _outText(String text, [int line]) {
    if (line == null) line = _line;
    final pre = _current.pre;
    int i = 0, j;
    while ((j = text.indexOf('"""', i)) >= 0) {
      if (line != null) {
        _writeln("\n$pre//#$line");
        line = null;
      }
      _writeln('$pre${_toTripleQuot(text.substring(i, j))}\n'
        '${pre}response.write(\'"""\');');
      i = j + 3;
    }
    if (i == 0) {
      _write('\n$pre${_toTripleQuot(text)}');
      if (line != null) _writeln(" //#$line");
    } else {
      _writeln('$pre${_toTripleQuot(text.substring(i))}');
    }
  }
  String _toTripleQuot(String text) {
    //Note: Dart can't handle """" (four quotation marks)
    var cb = text.startsWith('"') || text.indexOf('\n') >= 0 ? '\n': '', ce = "";
    if (text.endsWith('"')) {
      ce = '\\"';
      text = text.substring(0, text.length - 1);
    }
    return 'response.write("""$cb$text$ce""");';
  }

  void _outExpr() {
    //it doesn't push, so we have to use _line instead of _current.line
    final line = _line; //_tagData might have multiple lines
    final expr = _tagData(ignoreSlash: true, skipFollowingSpaces: false);
      //1) '/' is NOT a terminal, 2) no skip space for expression
    if (!expr.isEmpty) {
      final pre = _current.pre;
      _writeln('\n${pre}response.write(\$nns($expr)); //#${line}\n');
    }
  }

  ///merge partOf, and returns the library name
  String _mergePartOf(Set<String> imports) {
    if (destinationName == null)
      _error("The partOf attribute refers to a dart file is allowed only if destination is specified");

    Path libpath = new Path(_partOf),
        mypath = new Path(destinationName);
    if (!libpath.isAbsolute)
      libpath = mypath.directoryPath.join(libpath);
    mypath = mypath.relativeTo(libpath.directoryPath);

    File libfile = new File.fromPath(libpath);
    if (!libfile.existsSync()) {
      String libnm = libpath.filename;
      libnm = libnm.substring(0, libnm.indexOf('.')).toString();
        //filename must end with .dart (but it might have other extension ahead)

      final buf = new StringBuffer()
        ..write("library ")..write(libnm)..writeln(";\n");
      for (final impt in imports)
        buf.writeln("import ${_toImport(impt)};");
      buf..write("\npart '")..write(mypath)..writeln("';");
      libfile.writeAsStringSync(buf.toString(), encoding: encoding);
      return libnm;
    }

    //parse libfile (TODO: use a better algorithm to parse rather than readAsStringSync/writeAsStringSync)
    String libnm;
    bool comment0 = false, comment1 = false;
    Set<String> libimports = new Set(), libparts = new Set();
    final data = libfile.readAsStringSync();
    int len = data.length, importPos, partPos = len;
    for (int i = 0, j; i < len; ++i) {
      final cc = data[i];
      if (comment0) { //look for \n
        if (cc == '\n')
          comment0 = false;
      } else if (comment1) {
        if (cc == '*' && i + 1 < len && data[i + 1] == '/') {
          ++i;
          comment1 = false;
        }
      } else if (cc == '/') {
        if (i + 1 < len) {
          final c2 = data[i + 1];
          comment0 = c2 == '/';
          comment1 = c2 == '*';
          if (comment0 || comment1)
            ++i;
        }
      } else if ((j = _startsWith(data, i, "library")) >= 0) {
        i = _skipWhitespace(data, j);
        j = data.indexOf(';', i);
        if (j < 0)
          _error("Illegal library syntax found in $libfile");
        libnm = data.substring(i, j).trim();
        i = j;
      } else if ((j = _startsWith(data, i, "import")) >= 0) {
        i = _skipWhitespace(data, j);
        j = data.indexOf(';', i);
        if (j < 0)
          _error("Illegal import syntax found in $libfile");
        libimports.add(data.substring(i, j).trim().replaceAll('"', "'").replaceAll('\\', '/'));
        i = j;
      } else if ((j = _startsWith(data, i, "part")) >= 0) {
        if (importPos == null)
          importPos = i;
        i = _skipWhitespace(data, j);
        j = data.indexOf(';', i);
        if (j < 0)
          _error("Illegal part syntax found in $libfile");
        libparts.add(data.substring(i, j).trim().replaceAll('"', "'").replaceAll('\\', '/'));
        i = j;
      } else if (!StringUtil.isChar(cc, whitespace: true)) {
        partPos = i;
        break;
      }
    }

    if (libnm == null)
      _error("The library directive not found in $libfile");

    List<String> importToAdd = [];
    for (final impt in imports) {
      final s = _toImport(impt);
      if (!libimports.contains(s))
        importToAdd.add(s);
    }

    String mynm = "'$mypath'";
    if (libparts.contains(mynm))
      mynm = null; //no need to add

    if (!importToAdd.isEmpty || mynm != null) {
      final srcnm = sourceName != null ? sourceName: mypath.toString();
      final buf = new StringBuffer();

      if (importToAdd.isEmpty) {
        buf.write(data.substring(0, partPos));
      } else {
        if (importPos == null)
          importPos = partPos;
        buf.write(data.substring(0, importPos));
        for (final impt in importToAdd)
          buf..write("import ")..write(impt)..writeln("; //auto-inject from $srcnm");
        buf..write('\n')..write(data.substring(importPos, partPos));
      }

      if (mynm != null)
        buf..write("part ")..write(mynm)..writeln("; //auto-inject from $srcnm\n");
      buf.write(data.substring(partPos));

      libfile.writeAsStringSync(buf.toString(), encoding: encoding);
    }
    return libnm;
  }

  ///Generate import xxx;
  String _toImport(String impt) {
    impt = impt.trim();
    for (int i = 0, len = impt.length; i < len; ++i)
      if (StringUtil.isChar(impt[i], whitespace: true))
        return "'${impt.substring(0, i)}'${impt.substring(i)}";
    return "'$impt'";
  }

  void _write(String str) {
    _current.write(str);
  }
  void _writeln([String str]) {
    if (?str) _current.writeln(str);
    else _current.writeln();
  }

  String _toComment(String text) {
    text = text.replaceAll("\n", "\\n");
    return text.length > 30 ? "${text.substring(0, 27)}...": text;
  }

  ///Throws an exception if the value is EL
  void _noEL(String val, String what, [int line]) {
    if (val != null && isEL(val))
      _error("Expression not allowed in $what", line);
  }
  ///Throws an exception (and stops execution).
  void _error(String message, [int line]) {
    throw new SyntaxError(sourceName, line != null ? line: _current.line, message);
  }
  ///Display an warning.
  void _warning(String message, [int line]) {
    print("$sourceName:${line != null ? line: _current.line}: Warning! $message");
  }
  ///Display a message.
  void _info(String message, [int line]) {
    print("$sourceName:${line != null ? line: _current.line}: $message");
  }

  void push(Tag tag) {
    _tagCtxs.add(_current = new _TagContext.child(_current, tag, _line));
  }
  void pop() {
    final prev = _tagCtxs.removeLast();
    _current = _tagCtxs.last;
  }
}

///Syntax error.
class SyntaxError implements Error {
  String _msg;
  ///The source name
  final String sourceName;
  ///The line number
  final int line;

  SyntaxError(this.sourceName, this.line, String message) {
    _msg = "$sourceName:$line: $message";
  }
  String get message => _msg;
}

class _TagContext extends TagContext {
  String _pre;

  ///The line number
  final int line;

  _TagContext.root(Compiler compiler, IOSink output)
    : _pre = "", line = 1, super(null, null, compiler, output);
  _TagContext.child(_TagContext prev, Tag tag, this.line)
    : _pre = prev._pre, super(prev, tag, prev.compiler, prev.output);

  @override
  String nextVar() => "_${compiler._nextVar++}";
  @override
  String get pre => compiler._extra.isEmpty ? _pre: "${compiler._extra}$_pre";
  @override
  String indent() => _pre = "$_pre  ";
  @override
  String unindent() => _pre = _pre.isEmpty ? _pre: _pre.substring(2);

  @override
  void error(String message, [int line]) {
    compiler._error(message, line);
  }
  @override
  void warning(String message, [int line]) {
    compiler._warning(message, line);
  }
  String toString() => "($line: $tag)";
}
class _Expr {
}
class _Closing {
  final String name;
  _Closing(this.name);
}
class _IncInfo {
  ///The statement to generate. If null, it means URI is included (rather than handler)
  final String invocation;
  _IncInfo(this.invocation);
}
///Queued tag
class _QuedTag {
  Tag tag;
  String data;
  _QuedTag(this.tag, this.data);
}

int _startsWith(String data, int i, String pattern) {
  for (int len = data.length, pl = pattern.length, j = 0;; ++i, ++j) {
    if (j >= pl)
      return i; //found
    if (i >= len || data[i] != pattern[j])
      return -1;
  }
}
int _skipWhitespace(String data, int i) {
  for (int len = data.length; i < len && StringUtil.isChar(data[i], whitespace: true); ++i)
    ;
  return i;
}
