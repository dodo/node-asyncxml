{ EventEmitter } = require 'events'
{ deep_merge, indent, new_attrs, safe } = require './util'
EVENTS = ['add', 'attr', 'attr:remove', 'text', 'remove', 'close']

new_tag = (builder, name, attrs, children, opts) ->
    unless typeof attrs is 'object'
        [opts, children, attrs] = [children, attrs, {}]
    else
        # if attrs is an object and you want to use opts, make children null
        attrs ?= {}
    opts ?= {}
    pipe = {}
    opts.level ?= @level+1

    circular = 'default':@opts.builder, 'input':opts.builder
    opts.builder = @opts.builder = null
    opts = deep_merge @opts, opts # possibility to overwrite existing opts, like pretty
    @opts.builder = circular['default']
    opts.builder = circular['input'] or @opts.builder

    @pending.push tag = new (builder.Tag) name, attrs, null, opts

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
    tag.children children, opts if children?
    return tag



class Tag extends EventEmitter
    constructor: (@name, @attrs, children, @opts) ->
        unless typeof @attrs is 'object'
            [@opts, children, @attrs] = [children, @attrs, {}]
        else
            # if attrs is an object and you want to use opts, make children null
            @attrs ?= {}
            @opts ?= {}
        @level = @opts.level
        @builder = @opts.builder #or new Builder # inheritence
        @buffer = [] # after this tag all children emitted data
        @pending = [] # no open child tag
        @closed = false
        @writable = true
        @content = ""
        @headers = "<#{@name}#{new_attrs @attrs}"
        @children children, @opts

    tag: (args...) =>
        @builder._new_tag.apply this, [this].concat args

    $tag: (args...) =>
        @builder._new_sync_tag.apply this, [this].concat args

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

    children: (children) =>
        return this unless children?
        if typeof children is 'function'
            children.call this
        else
            @text children
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
        @emit 'data', "#{indent this}#{content}" if content # FIXME is this really nessary?
        @content += content
        true

    up: () -> @builder # this node has no parent

    end: () =>
        if not @closed or @closed is 'pending'
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
        @builder = this
        @buffer = [] # for child output
        @closed = no
        @pending = [] # no open child tag
        @opts.builder ?= this
        @opts.pretty ?= off
        @level = @opts.level ? 0
        @Tag = @opts.Tag or Tag

    _new_tag: (parent, args...) =>
        if parent.headers
            parent.emit 'data', "#{indent parent}#{parent.headers}>"
            delete parent.headers
        new_tag.apply parent, [this].concat args

    _new_sync_tag: (parent, name, attrs, children, opts) =>
        # sync tag, - same as normal tag, but closes it automaticly
        unless typeof attrs is 'object'
            [opts, children, attrs] = [children, attrs, {}]
        else
            attrs ?= {}
        opts ?= {}
        self_ending_children_scope = ->
            @children children
            @end()
        @_new_tag parent, name, attrs, self_ending_children_scope, opts

    tag: (args...) =>
        @level--
        tag = @_new_tag.apply this, [this].concat args
        @level++
        tag

    $tag: (args...) =>
        @level--
        tag = @_new_sync_tag.apply this, [this].concat args
        @level++
        tag

    end: (data) =>
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



