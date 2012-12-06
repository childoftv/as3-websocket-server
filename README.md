# as3 Websocket Server

A simple websocket server that will allow you to connect from recent versions of chrome/firefox (inc. mobile editions) using the ws:// syntax.

Released under MIT LICENSE, see the LICENSE.md for details

## Install

After git checkout or download add the src folder to you source folders in Flash Builder.

## Usage

Please look at WebSocketServerBasic.as for a simple usage example.

## Release notes Dec 2012:

Right now the server does not handle continuations so short messages work fine but very long ones may not. This feature is slated to come in early 2013.

If you wish to port the server to work on Air for mobile there are some available native extensions which might help. I'm reviewing these and may integrate them soon.
