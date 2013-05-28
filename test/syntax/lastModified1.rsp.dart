//Auto-generated by RSP Compiler
//Source: test/syntax/lastModified1.rsp.html
library lastModified1_rsp;

import 'dart:async';
import 'dart:io';
import 'package:stream/stream.dart';

/** Template, lastModified1, for rendering the view. */
Future lastModified1(HttpConnect connect, {input}) { //#2
  var _t0_, _cs_ = new List<HttpConnect>(),
  request = connect.request, response = connect.response;

  if (!connect.isIncluded)
    response.headers.contentType = ContentType.parse("""text/html; charset=utf-8""");
  response.headers.set(HttpHeaders.LAST_MODIFIED, new DateTime.fromMillisecondsSinceEpoch(1369708684926));

  response.write("""
<html>
  <head>
    <title></title>
  </head>
  <body>
    """); //#2

  response.write(RSP.nnx(input.whatever * input.another, encode: 'none', maxlength: 20)); //#7


  response.write("""

  </body>
</html>
"""); //#7

  return RSP.nnf();
}
