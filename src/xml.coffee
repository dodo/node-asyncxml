{ EventEmitter } = require 'events'
{ deep_merge, indent, new_attrs, safe } = require './util'
EVENTS = ['add', 'attr', 'attr:remove', 'text', 'remove', 'close']

new_tag = (name, attrs, children, opts) ->
    unless typeof attrs is 'object'
        [opts, children, attrs] = [children, attrs, {}]
    else
        # if attrs is an object and you want to use opts, make children null
        attrs ?= {}
    opts ?= {}
    pipe = {}
    opts.level = @level+1
    opts = deep_merge @opts, opts # possibility to overwrite existing opts, like pretty

    { direct } = opts
    _children = children
    _children = undefined if direct

    @pending.push tag = new @Tag name, attrs, _children, opts

    tag.up = (opts = {}) => # set parent
        opts.end ?= true
        tag.end.apply tag, arguments if opts.end
        this

    tag.on 'data', pipe.data = (data) =>
        if @pending[0] is tag
            @emit 'data', data
        else
            @buffer.push data

    EVENTS.forEach (event) =>
        tag.on event, pipe[event] = (args...) =>
            @emit event, args...

    tag.on 'end', on_end = (data) =>
        @buffer.push data unless data is undefined
        tag.removeListener 'end', on_end
        if @pending[0] is tag
            if tag.pending.length
                tag.pending[0].once 'end', ->
                    on_end()
            else
                if tag.buffer.length
                    @buffer = @buffer.concat tag.buffer
                    tag.buffer = []
                @pending = @pending.slice(1)
                tag.removeListener 'data', pipe.data
                for event in EVENTS
                    tag.removeListener event, pipe[event]
                if @buffer.length
                    for data in @buffer
                        @emit 'data', data
                    @buffer = []
                if @closed and @pending.length is 0
                    @end()
        else
            for known, i in @pending
                if tag is known
                    @pending = @pending.slice(0,i).concat @pending.slice i+1
                    if @buffer.length
                        before = @pending[i-1]
                        before.buffer = before.buffer.concat @buffer
                        @buffer = []
                    tag.removeListener 'data', pipe.data
                    for event in EVENTS
                        tag.removeListener event, pipe[event]
                    if @closed is 'pending'
                        @end()
                    return
            throw new Error("this shouldn't happen D:")
        return

    @emit 'add', tag
    tag.children children, opts if direct
    return tag


sync_tag = (name, attrs, children, opts) ->
    unless typeof attrs is 'object'
        [opts, children, attrs] = [children, attrs, {}]
    else
        attrs ?= {}
    opts ?= {}
    opts.direct ?= yes
    self_ending_children_scope = ->
        @children children, direct:yes
        @end()
    @tag.call this, name, attrs, self_ending_children_scope, opts


class Tag extends EventEmitter
    constructor: (@name, @attrs, children, @opts) ->
        unless typeof @attrs is 'object'
            [@opts, children, @attrs] = [children, @attrs, {}]
        else
            # if attrs is an object and you want to use opts, make children null
            @attrs ?= {}
            @opts ?= {}
        @level = @opts.level
        @Tag = @opts.Tag or Tag # inherit (maybe) extended tag class
        @buffer = [] # after this tag all children emitted data
        @pending = [] # no open child tag
        @_delayed = null # delayed method calls (null means it's off)
        @closed = false
        @writable = true
        @content = ""
        @headers = "<#{@name}#{new_attrs @attrs}"
        @children children, @opts

    $tag: =>
        # sync tag, - same as normal tag, but closes it automaticly
        sync_tag.apply this, arguments

    tag: =>
        if @headers
            @emit 'data', "#{indent this}#{@headers}>"
            delete @headers
        new_tag.apply this, arguments

    attr: (key, value) =>
        if typeof key is 'string'
            return @attrs[key] if @attrs[key] and not value
            @attrs[key] = value
            @emit 'attr', this, key, value
        else
            for own k, v of key
                @attrs[k] = v
                @emit 'attr', this, k, v
        @headers = "<#{@name}#{new_attrs @attrs}" if @headers
        this

    removeAttr: (key) =>
        if typeof key is 'string'
            delete @attrs[key]
            @emit 'attr:remove', this, key
        else
            for own k, v of key
                delete @attr[key]
                @emit 'attr:remove', this, key
        @headers = "<#{@name}#{new_attrs @attrs}" if @headers
        this

    children: (children, {direct} = {}) =>
        return this unless children?
        unless typeof children is 'function'
            content = children
            children = =>
                @text content
        if direct
            children.call this
        else
            @_delayed = [] # mark that this tag has a delayed children scope
            process.nextTick =>
                [delayed, @_delayed] = [@_delayed, null] # turn off
                children.call this
                for method in delayed
                    method.call this
        this

    text: (content, opts = {}) =>
        return @content unless content? or opts.force
        @write(content, opts)
        @content = content
        @emit 'text', this, content
        this

    write: (content, {escape} = {}) =>
        content = safe(content) if escape
        if @headers
            @emit 'data', "#{indent this}#{@headers}>"
            delete @headers
        @emit 'data', "#{indent this}#{content}" if content
        @content += content
        true

    up: () -> null # this node has no parent

    end: () =>
        if @_delayed?
            @closed = 'delayed'
            @_delayed.push @end
            return this
        if not @closed or @closed is 'delayed' or @closed is 'pending'
            if @headers
                data = "#{indent this}#{@headers}/>"
                @closed = 'self'
            else
                data = "#{indent this}</#{@name}>"
                if @pending.length
                    @closed = 'pending'
                else
                    @closed = yes
            @emit 'close', this
            @emit 'end', data unless @closed is 'pending'
        else if @closed is 'removed'
            @emit 'end'
        else
            @closed = yes
        @writable = false
        this

    toString: () =>
        "<#{@name}#{new_attrs @attrs}" +
            if @closed is 'self'
                "/>"
            else if @closed
                ">#{@content}</#{@name}>" # FIXME children ?

    remove: () =>
        @closed = 'removed' unless @closed
        @emit 'remove', this
        this


class Builder extends EventEmitter
    constructor: (@opts = {}) ->
        @buffer = [] # for child output
        @closed = no
        @pending = [] # no open child tag
        @opts.Tag ?= Tag
        @opts.pretty ?= off
        @level = @opts.level ? 0
        @Tag = @opts.Tag or Tag

    tag: =>
        @level--
        tag = new_tag.apply this, arguments
        @level++
        tag

    $tag: (args...) =>
        # sync tag, - same as normal tag, but closes it automaticly
        sync_tag.apply this, arguments

    end: (data) =>
        if @_delayed?
            @closed = 'delayed'
            @_delayed.push =>
                @end(data)
            return this
        if @pending.length
            @closed = 'pending'
            @pending[0].once 'end', =>
                @end(data)
        else
            @emit 'data', "#{indent this}#{data}" if data
            @emit 'end' if not @closed or @closed is 'pending'
            @closed = yes
        this


# exports

module.exports = { Tag, Builder }



