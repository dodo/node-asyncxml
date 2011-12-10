{ EventEmitter } = require 'events'
{ deep_merge, prettify, new_attrs, safe } = require './util'
EVENTS = ['add', 'attr', 'attr:remove', 'text', 'remove', 'close']


parse_args = (name, attrs, children, opts) ->
    unless typeof attrs is 'object'
        [opts, children, attrs] = [children, attrs, {}]
    else
        # if attrs is an object and you want to use opts, make children null
        attrs ?= {}
    opts ?= {}
    return [name, attrs, children, opts]

flush = ->
    if @buffer.length
        @write data for data in @buffer
        @buffer = []

rmevents = (events) ->
    @removeListener 'data', events.data
    @removeListener event, events[event] for event in EVENTS

new_tag = ->
    [name, attrs, children, opts] = parse_args arguments...
    events = {}
    opts.level ?= @level+1

    opts = deep_merge @builder.opts, opts # possibility to overwrite existing opts, like pretty
    opts.builder = @builder

    newtag = new @builder.Tag name, attrs, null, opts
    newtag.parent = this

    # only when the builder approves the new tag we can proceed with announcing
    # the new tag to the parent and to the tree and apply the childrenscope
    @builder.approve this, newtag, (_, tag) =>

        tag.on 'data', events.data = (data) =>
            if @pending[0] is tag
                @write data
            else
                @buffer.push data

        pipe = (event) =>
            tag.on event, events[event] = =>
                @emit event, arguments...
        pipe event for event in EVENTS

        tag.once 'end', on_end = =>
            if @pending[0] is tag
                if tag.pending.length
                    tag.pending[0].once 'end', on_end
                else
                    if tag.buffer.length
                        @buffer = @buffer.concat tag.buffer
                        tag.buffer = []
                    @pending = @pending.slice(1)
                    rmevents.call tag, events
                    flush.call this
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
                        rmevents.call tag, events
                        if @closed is 'pending'
                            flush.call this
                            @end()
                        return
                throw new Error("this shouldn't happen D:")
            return

        @pending.push tag
        @emit 'new', tag
        @emit 'add', tag
        tag.children children, opts if children?
    return newtag # hopefully this is still the same after the approval

sync_tag = ->
    [name, attrs, children, opts] = parse_args arguments...
    self_ending_children_scope = ->
        @children children
        @end()
    new_tag.call this, name, attrs, self_ending_children_scope, opts



class Tag extends EventEmitter
    constructor: ->
        [@name, @attrs, children, opts] = parse_args arguments...
        @pretty = opts.pretty ? off
        @level = opts.level
        @builder = opts.builder #or new Builder # inheritence
        @buffer = [] # after this tag all children emitted data
        @pending = [] # no open child tag
        @parent = @builder
        @closed = false
        @writable = true
        @isempty = yes
        @content = ""
        @children children, opts
        @$tag = sync_tag
        @tag = new_tag

    emit: =>
        if @builder.closed is yes and @parent.closed is yes
            @builder.emit arguments...
        else super

    attr: (key, value) =>
        if typeof key is 'string'
            if not value? and ((attr = @builder.query 'attr', this, key))?
                # sync it and return value
                @attrs[key] = attr
                return attr
            @attrs[key] = value
            @emit 'attr', this, key, value
        else
            for own k, v of key
                @attrs[k] = v
                @emit 'attr', this, k, v
        this

    removeAttr: (key) =>
        if typeof key is 'string'
            delete @attrs[key]
            @emit 'attr:remove', this, key
        else
            for own k, v of key
                delete @attr[key]
                @emit 'attr:remove', this, key
        this

    children: (children) =>
        return this unless children?
        if typeof children is 'function'
            children.call this
        else
            @text children
        this

    text: (content, opts = {}) =>
        unless content? or opts.force
            return @content = @builder.query 'text', this
        content = safe(content) if opts.escape
        @write content, deep_merge(opts, escape:off) # dont double escape
        if opts.append
            @content += content
        else
            @content  = content
        @emit 'text', this, @content
        this

    write: (content, {escape} = {}) =>
        content = safe(content) if escape
        if @isempty
            @emit 'data', prettify this, "<#{@name}#{new_attrs @attrs}>"
            @isempty = no
        @emit 'data', prettify this, "#{content}" if content
        true

    up: (opts = {}) =>
        opts.end ?= true
        @end arguments... if opts.end
        @parent

    end: () =>
        if not @closed or @closed is 'pending'
            if @pending.length
                @closed = 'pending'
            else
                if @isempty
                    data = "<#{@name}#{new_attrs @attrs}/>"
                    @closed = 'self'
                else
                    data = "</#{@name}>"
                    @closed = yes
                @emit 'data', prettify this, data
                @emit 'close', this
                @emit 'end'
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
        # values
        @builder = this
        @buffer = [] # for child output
        @pending = [] # no open child tag
        @checkers = [] # all the middlewares that have to approve a new tag
        # states
        @closed = no
        # defaults
        @opts.pretty ?= off
        @level = @opts.level ? -1
        # api
        @Tag = Tag
        @tag = new_tag
        @$tag = sync_tag

    write: (data) =>
        @emit 'data', data

    end: () =>
        if @pending.length
            @closed = 'pending'
            @pending[0].once 'end', @end
        else
            @emit 'end' if not @closed or @closed is 'pending'
            @closed = yes
        this

    # intern getter to let intern tag structure stay in sync with eg dom
    query: (type, tag, key) ->
        if type is 'attr'
            tag.attrs[key]
        else if type is 'text'
            tag.content

    use: (checker) ->
        @checkers.push checker

    approve: (parent, tag, callback) ->
        checkers = @checkers.slice()
        next = (tag) ->
            checker = checkers.shift() ? callback
            checker parent, tag, next
        next(tag)

# exports

module.exports = { Tag, Builder }



