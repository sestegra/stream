//Auto-generated by RSP Compiler
//Source: lastModified1.rsp.html
library lastModified1_rsp;

import 'dart:async';
import 'dart:io';
import 'package:stream/stream.dart';

/** Template, lastModified1, for rendering the view. */
Future lastModified1(HttpConnect connect, {input}) { //#2
  var _t0_, _cs_ = new List<HttpConnect>();
  HttpRequest request = connect.request;
  HttpResponse response = connect.response;
  Rsp.init(connect, "text/html; charset=utf-8",
    () => new DateTime.fromMillisecondsSinceEpoch(1371822684138));

  response.write("""<html>
  <head>
    <title></title>
  </head>
  <body>
    """); //#2

  response.write(Rsp.nnx(input.whatever * input.another, encode: 'none', maxlength: 20)); //#7


  response.write("""

  </body>
</html>
"""); //#7

  return Rsp.nnf();
}
