//Auto-generated by RSP Compiler
//Source: ../includerView.rsp.html
part of features;

/** Template, includerView, for rendering the view. */
Future includerView(HttpConnect connect) { //#2
  var _t0_, _cs_ = new List<HttpConnect>();
  HttpRequest request = connect.request;
  HttpResponse response = connect.response;
  Rsp.init(connect, "text/html; charset=utf-8");
final infos = {
  "fruits": ["apple", "orange", "lemon"],
  "cars": ["bmw", "audi", "honda"]
};

  response.write("""

<html>
  <head>
    <title>Test of Include</title>
    <link href="/theme.css" rel="stylesheet" type="text/css" />
  </head>
  <body>
    <ul>
      <li>You shall see something inside the following two boxes.</li>
    </ul>
    <div style="border: 1px solid blue">
"""); //#7

  return connect.include("/frag.html").then((_) { //include#18

    response.write("""    </div>
    <div style="border: 1px solid red">
"""); //#19

    return Rsp.nnf(fragView(new HttpConnect.chain(connect), infos: infos)).then((_) { //include#21

      response.write("""    </div>
    <div style="border: 1px solid red">
"""); //#22

      var _0 = new StringBuffer(); _cs_.add(connect); //var#25
      connect = new HttpConnect.stringBuffer(connect, _0); response = connect.response;

      response.write("""  <h1>This is a header</h1>
  <p>Passed from the includer for showing """); //#26

      response.write(Rsp.nnx(infos)); //#27


      response.write("""</p>
"""); //#27

      connect = _cs_.removeLast(); response = connect.response;

      var _1 = new StringBuffer(); _cs_.add(connect); //var#29
      connect = new HttpConnect.stringBuffer(connect, _1); response = connect.response;

      response.write("""  <h2>This is a footer</h2>
  <p>It also includes another page:</p>
"""); //#30

      return connect.include("/frag.html").then((_) { //include#32

        connect = _cs_.removeLast(); response = connect.response;

        return Rsp.nnf(fragView(new HttpConnect.chain(connect), infos: infos, header: _0.toString(), footer: _1.toString())).then((_) { //include#24

          response.write("""    </div>
  </body>
</html>
"""); //#35

          return Rsp.nnf();
        }); //end-of-include
      }); //end-of-include
    }); //end-of-include
  }); //end-of-include
}
