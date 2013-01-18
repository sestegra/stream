#Stream

[Stream](http://rikulo.org) is a Dart web server supporting URI mapping, template technology, file-based static resources and MVC design pattern.

* [Home](http://rikulo.org)
* [Documentation](http://docs.rikulo.org/stream/latest)
* [API Reference](http://api.rikulo.org/stream/latest)
* [Discussion](http://stackoverflow.com/questions/tagged/rikulo-stream)
* [Issues](https://github.com/rikulo/stream/issues)

Stream is distributed under an Apache 2.0 License.

##Install from Dart Pub Repository

Add this to your `pubspec.yaml` (or create it):

    dependencies:
      stream:

Then run the [Pub Package Manager](http://pub.dartlang.org/doc) (comes with the Dart SDK):

    pub install

For more information, please refer to [Stream: Getting Started](http://docs.rikulo.org/stream/latest/Getting_Started/) and [Pub: Getting Started](http://pub.dartlang.org/doc).

##Install from Github for Bleeding Edge Stuff

To install stuff that is still in development, add this to your `pubspec.yam`:

    dependencies:
      stream:
        git: git://github.com/rikulo/stream.git

For more information, please refer to [Pub: Dependencies](http://pub.dartlang.org/doc/pubspec.html#dependencies).

##Usage

*(Under Construction)* Please refer to the following examples:

* [Hello Static Resources](https://github.com/rikulo/stream/tree/master/example/hello-static)
* [Hello Dynamic Contents](https://github.com/rikulo/stream/tree/master/example/hello-dynamic)
* [Hello Templates](https://github.com/rikulo/stream/tree/master/example/hello-template)
* [Hello MVC](https://github.com/rikulo/stream/tree/master/example/hello-mvc)

###Compile RSP (Rikulo Stream Page) to dart files

There are two ways to compile RSP files into dart files: automatic building with Dart Editor or manual compiling.

> RSP is a template technology allowing developers to create dynamically generated web pages based on HTML, XML or other document types. Please refer [here](https://github.com/rikulo/stream/blob/master/example/hello-mvc/webapp/listView.rsp.html) and [here](https://github.com/rikulo/stream/blob/master/test/features/webapp/includerView.rsp.html).

###Build with Dart Editor

To compile your RSP files automatically, you just need to add a build.dart file in the root directory of your project, with the following content:

    import 'package:stream/rspc.dart';
    void main() {
      build(new Options().arguments);
    }

With this build.dart script, whenever your RSP is modified, it will be re-compiled.

###Compile Manually

To compile a RSP file manually, run `rspc` (RSP compiler) to compile it into the dart file with [command line interface](http://en.wikipedia.org/wiki/Command-line_interface) as follows:

    dart bin/rspc.dart your-rsp-file(s)

A dart file is generated for each RSP file you gave.

##Notes to Contributors

###Fork Stream

If you'd like to contribute back to the core, you can [fork this repository](https://help.github.com/articles/fork-a-repo) and send us a pull request, when it is ready.

Please be aware that one of Stream's design goals is to keep the sphere of API as neat and consistency as possible. Strong enhancement always demands greater consensus.

If you are new to Git or GitHub, please read [this guide](https://help.github.com/) first.
