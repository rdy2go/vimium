class UIComponent
  iframeElement: null
  iframePort: null
  showing: null
  options: null

  constructor: (iframeUrl, className, @handleMessage) ->
    @iframeElement = document.createElement "iframe"
    @iframeElement.className = className
    @iframeElement.seamless = "seamless"
    @iframeElement.src = chrome.runtime.getURL iframeUrl
    @iframeElement.addEventListener "load", => @openPort()
    document.documentElement.appendChild @iframeElement
    @showing = true # The iframe is visible now.
    # Hide the iframe, but don't interfere with the focus.
    @hide false

    # If any other frame in the current tab receives the focus, then we hide the UI component.
    # NOTE(smblott) This is correct for the vomnibar, but might be incorrect (and need to be revisited) for
    # other UI components.
    chrome.runtime.onMessage.addListener (request) =>
      @hide false if @showing and request.name == "frameFocused" and request.focusFrameId != frameId
      false # Free up response handler.

  # Open a port and pass it to the iframe via window.postMessage.
  openPort: ->
    messageChannel = new MessageChannel()
    @iframePort = messageChannel.port1
    @iframePort.onmessage = (event) => @handleMessage event

    # Get vimiumSecret so the iframe can determine that our message isn't the page impersonating us.
    chrome.storage.local.get "vimiumSecret", ({vimiumSecret: secret}) =>
      @iframeElement.contentWindow.postMessage secret, chrome.runtime.getURL(""), [messageChannel.port2]

  postMessage: (message) ->
    @iframePort.postMessage message

  activate: (@options) ->
    @postMessage @options if @options?
    @show() unless @showing
    @iframeElement.focus()

  show: (message) ->
    @postMessage message if message?
    @iframeElement.classList.remove "vimiumUIComponentHidden"
    @iframeElement.classList.add "vimiumUIComponentShowing"
    # The window may not have the focus.  We focus it now, to prevent the "focus" listener below from firing
    # immediately.
    window.focus()
    window.addEventListener "focus", @onFocus = (event) =>
      if event.target == window
        window.removeEventListener "focus", @onFocus
        @onFocus = null
        @postMessage "hide"
    @showing = true

  hide: (focusWindow = true)->
    @iframeElement.classList.remove "vimiumUIComponentShowing"
    @iframeElement.classList.add "vimiumUIComponentHidden"
    window.removeEventListener "focus", @onFocus if @onFocus
    @onFocus = null
    if focusWindow and @options?.sourceFrameId?
      chrome.runtime.sendMessage
        handler: "sendMessageToFrames"
        message:
          name: "focusFrame"
          frameId: @options.sourceFrameId
          highlight: true # true for debugging; should be false when live.
    @options = null
    @showing = false

root = exports ? window
root.UIComponent = UIComponent
