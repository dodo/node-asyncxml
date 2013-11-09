{ EventEmitter } = require 'events'
{ new_attrs, safe } = require './util'
EVENTS = ['add', 'attr', 'data', 'text', 'raw', 'show', 'hide', 'remove',
          'replace', 'close']

# could be boosted up by using a c lib → https://github.com/wezm/node-genx
# TODO add clone method to tag so tags can be cloned (param: deep for deep copy)
# TODO partials?

parse_args = (name, attrs, children, opts) ->
    unless typeof attrs is 'object'
        [attrs, children, opts] = [{}, attrs, children]
    else
        # if attrs is an object and you want to use opts, make children null
        attrs ?= {}
    opts ?= {}
    return [name, attrs, children, opts]


connect_tags = (parent, child) ->
    listeners = {}
    pipe = (event) ->
        return if listeners[event]?
        child.on? event, listeners[event] = ->
            parent.emit(event, arguments...)
    wire = ->
        pipe event for event in EVENTS
    dispose = ->
        for event in EVENTS
            if (listener = listeners[event])?
                child.removeListener?(event, listener)
                listeners[event] = undefined
    remove = (soft, noremove) ->
        if this is child
            parent.removeListener('removed', remove)
            parent.removeListener('replaced', replace)
            child.removeListener('replaced', replace)
            dispose()
        else if soft
            parent.once('removed', remove)
        else
            child.removeListener('removed', remove)
            parent.removeListener('replaced', replace)
            child.removeListener('replaced', replace)
            dispose()
            child.remove() unless noremove
    replace = (tag) ->
        if this is child
            remove.call(parent, no, yes)
            child = tag
            wire()
        else
            parent.removeListener('removed', remove)
            parent = tag
        tag.once('replaced', replace)
        tag.once('removed', remove)
    wire() # add
    child.once('removed', remove)
    parent.once('removed', remove)
    child.once('replaced', replace)
    parent.once('replaced', replace)


add_tag = (newtag, callback) ->
    return callback?.call(this) unless newtag?
    # only when the builder approves the new tag we can proceed with announcing
    # the new tag to the parent and to the tree and apply the childrenscope
    wire_tag = (_, tag) =>
        tag.builder ?= @builder
        tag.parent  ?= this
        tag.builder.opts.pretty = @builder.opts.pretty
        tag.builder.level = @level

        connect_tags(this, tag)

        @emit 'add', this, tag
        @emit 'new', tag
        @isempty = no
        tag.emit? 'close', tag if tag.closed
        callback?.call(this, tag)

    newtag.parent = this
    if @builder?
        @builder.approve('new', this, newtag, wire_tag)
    else
        wire_tag(this, newtag)

new_tag = ->
    [name, attrs, children, opts] = parse_args arguments...
    opts.level ?= @level+1
    opts.pretty ?= @builder?.opts.pretty
    opts.builder = @builder

    TagInstance = @builder?.Tag ? Tag
    newtag = new TagInstance name, attrs, null, opts
    callback = ((tag) -> tag.children children, opts) if children?
    add_tag.call this, newtag, callback
    return newtag # hopefully this is still the same after the approval

sync_tag = ->
    [name, attrs, children, opts] = parse_args arguments...
    self_ending_children_scope = ->
        @children children if children?
        @end()
    new_tag.call this, name, attrs, self_ending_children_scope, opts



class Tag extends EventEmitter
    constructor: ->
        [@name, @attrs, children, opts] = parse_args arguments...
        @pretty = opts.pretty ? off
        @level = opts.level ? 0
        @builder = opts.builder # inheritence
        @setMaxListeners(0)
        @parent = @builder
        @closed = no
        @writable = true
        @hidden = no
        @isready = no
        @isempty = yes
        @content = ""
        @children children, opts
        @$tag = sync_tag
        @tag = new_tag

    attr: (key, value) =>
        if typeof key is 'string'
            if value is undefined
                attr = @builder?.query('attr', this, key)
                # attr is not defined if attr is undefined
                # attr doesn't have a value when attr is null
                unless attr is undefined
                    # sync it and return value
                    @attrs[key] = attr
                return attr
            @attrs[key] = value
            @emit 'attr', this, key, value
        else
            for own k, v of key
                unless v is undefined
                    @attrs[k] = v
                else
                    delete @attr[key]
                @emit 'attr', this, k, v
        this

    removeAttr: (keys...) =>
        for key in keys
            delete @attrs[key]
            @emit 'attr', this, key, undefined
        this

    children: (children) =>
        return this unless children?
        if typeof children is 'function'
            children.call this
        else
            @text children
        this

    text: (content, opts = {}) =>
        unless content?
            return @content = @builder?.query 'text', this
        content = safe(content) if opts.escape
        if opts.append
            @content += content
        else
            @content  = content
        @emit('text', this, content)
        @isempty = no
        this

    raw: (html, opts = {}) =>
        @emit('raw', this, html)
        @isempty = no
        this

    write: (content, {escape, append} = {}) =>
        content = safe(content) if escape
        @emit 'data', this, "#{content}" if content
        if append ? yes
            @content += content
        else
            @content  = content
        @isempty = no
        true

    up: (opts = {}) =>
        opts.end ?= true
        @end arguments... if opts.end
        @parent

    show: () =>
        @hidden = no
        @emit 'show', this
        this

    hide: () =>
        @hidden = yes
        @emit 'hide', this
        this

    end: () =>
        if not @closed
            @closed = 'approving'
            close_tag = =>
                if @isempty
                    @closed = 'self'
                else
                    @closed = yes
                @emit 'close', this
                @writable = false
                set_ready = =>
                    @isready = yes
                    @emit 'ready'
                if @builder?
                    @builder.approve('ready', this, set_ready)
                else
                    set_ready()
                @emit 'end'
            if @builder?
                @builder.approve('end', this, close_tag)
            else
                close_tag(this, this)
        else if @closed is 'approving'
            # just wait
        else if @closed is 'removed'
            @emit 'end'
            @writable = false
        else
            @closed = yes
            @writable = false
        this

    toString: () =>
        "<#{@name}#{new_attrs @attrs}" +
            if @closed is 'self'
                "/>"
            else if @closed
                ">#{@content}</#{@name}>"
            else
                ">#{@content}"

    add: (rawtag, callback) =>
        tag = @builder?.query 'tag', this, rawtag
        tag = rawtag unless tag? or @builder?
        # TODO query result validation
        add_tag.call(this, tag, callback)
        this

    replace: (rawtag) =>
        tag = @builder?.query 'tag', this, rawtag
        tag = rawtag unless tag? or @builder?
        return this if this is tag
        tag.parent  ?= @parent
        tag.builder ?= @builder
        @emit 'replace', this, tag
        if @builder is tag.builder
            @builder = null
        @parent = null
        @emit 'replaced', tag # internal
        tag

    remove: (opts = {}) =>
        @closed = 'removed' unless opts.soft
        @emit 'remove', this, opts
        @builder = null unless this is @builder
        @parent = null
        @emit 'removed', opts.soft # internal
        @removeAllListeners() unless opts.soft
        this

    ready: (callback) =>
        if @isready
            callback?.call(this)
            return this
        @once 'ready', callback
        this


class Builder extends EventEmitter
    constructor: (@opts = {}) ->
        # methods
        @show = @show.bind(this)
        @hide = @hide.bind(this)
        @remove = @remove.bind(this)
        # values
        @builder = this
        @checkers = {} # all the middlewares that have to approve a new tag
        # states
        @closed = no
        @isempty = yes
        # defaults
        @opts.pretty ?= off
        @level = @opts.level ? -1
        @setMaxListeners(0)
        # api
        @Tag = Tag
        @tag = new_tag
        @$tag = sync_tag

    show: Tag::show
    hide: Tag::hide
    remove: Tag::remove
    replace: Tag::replace

    toString: ->
        "[object AsyncXMLBuilder]"

    add: (rawtag, callback) =>
        tag = @query 'tag', this, rawtag
        tag = rawtag unless tag?
        # TODO query result validation
        add_tag.call(this, tag, callback)
        this

    end: () =>
        @closed = yes
        @emit 'close', this # tag api
        @emit 'end'
        this

    ready: (callback) =>
        return callback?.call(this) if @closed is yes
        @once 'end', callback

    # intern getter to let intern tag structure stay in sync with eg dom
    query: (type, tag, key) ->
        if type is 'attr'
            tag.attrs[key]
        else if type is 'text'
            tag.content
        else if type is 'tag'
            key # this should be a tag

    register: (type, checker) ->
        unless type is 'new' or type is 'end' or type is 'ready'
            throw new Error "only type 'ready', 'new' or 'end' allowed."
        @checkers[type] ?= []
        @checkers[type].push checker

    approve: (type, parent, tag, callback) ->
        checkers = @checkers[type]?.slice?() ? []
        switch type
            when 'new'
                next = (tag) ->
                    checker = checkers.shift() ? callback
                    checker(parent, tag, next)

            when 'ready', 'end'
                [tag, callback] = [parent, tag] # shift arguments
                next = (tag) ->
                    checker = checkers.shift() ? callback
                    checker(tag, next)
            else
                throw new Error "type '#{type}' not supported."
        # start
        next(tag)

# exports

module.exports = { Tag, Builder }



