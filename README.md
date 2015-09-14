# Improving Rack

So this is an experiment and proof of concept to see if we could improve
Rack without losing compatibility.

# Core Goal

* Compatibility. But new features would only be available with new API.
* Compatibility is handled via `Rack::Builder2`
* Better encapsulation (Stop `Rack::Request.new(env)` all the way down)
* Easier streaming (mainly targeting HTTP/2)
* Remove Rack internal complexity (enough of `respond_to?`
  check and BodyProxy)

# Current Implementation

* Old middleware and application should work as if
* New middleware could take the advantage of new SPEC
  (`process_request(req, res)` for now)
* If no old middleware were trying to walk through the response body
  (e.g. `Rack::ContentLength`), the call stack from application wouldn't
  see middleware around. (now it's iterating rather than stacking)
* Old middleware would suffer from some performance penalty due to the
  new compatibility layer. Move to the new API to restore performance.

# Next Goal

* Access full response for new middleware (maybe via callback or buffer)
* Streaming for new middleware

# See Also

* [Rack 2.0, or Rack for the Future](https://gist.github.com/raggi/11c3491561802e573a47)
* Yesod's [Web Application Interface](http://www.yesodweb.com/book/web-application-interface), [source](https://github.com/yesodweb/wai).

``` haskell
type Application = Request -> (Response -> IO ResponseReceived) ->
                   IO ResponseReceived

type Middleware = Application -> Application
```
