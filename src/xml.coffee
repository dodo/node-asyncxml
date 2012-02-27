{ EventEmitter } = require 'events'
{ deep_merge, new_attrs, safe } = require './util'
EVENTS = ['add', 'attr', 'data', 'text', 'raw', 'show', 'hide', 'remove',
          'replace', 'close']


parse_args = (name, attrs, children, opts) ->
    unless typeof attrs is 'object'
        [opts, children, attrs] = [children, attrs, {}]
    else
        # if attrs is an object and you want to use opts, make children null
        attrs ?= {}
    opts ?= {}
    return [name, attrs, children, opts]


add_tag = (newtag, callback) ->
    return callback?.call(this) unless newtag?
    # only when the builder approves the new tag we can proceed with announcing
    # the new tag to the parent and to the tree and apply the childrenscope
    wire_tag = (_, tag) =>
        tag.builder ?= @builder
        tag.parent  ?= this

        pipe = (event) =>
            tag.on? event, =>
                @emit event, arguments...
        pipe event for event in EVENTS

        tag.once? 'end', on_end = =>
            if @pending[0] is tag
                if tag.pending.length
                    tag.pending[0].once 'end', on_end
                else
                    @pending = @pending.slice(1)
                    if @closed and @pending.length is 0
                        @end()
            else
                for known, i in @pending
                    if tag is known
                        @pending = @pending.slice(0,i).concat @pending.slice i+1
                        if @closed is 'pending'
                            @end()
                        return
                throw new Error("this shouldn't happen D:")
            return

        @pending.push tag if tag.closed is no
        @emit 'add', this, tag
        @isempty = no
        tag.emit? 'close', tag if tag.closed
        callback?.call(this, tag)

    if @builder?
        @builder.approve('new', this, newtag, wire_tag)
    else
        wire_tag(this, newtag)

new_tag = ->
    [name, attrs, children, opts] = parse_args arguments...
    opts.level ?= @level+1

    # possibility to overwrite existing opts, like pretty
    opts = deep_merge (@builder?.opts ? {}), opts
    opts.builder = @builder

    TagInstance = @builder?.Tag ? Tag
    newtag = new TagInstance name, attrs, null, opts
    newtag.parent = this
    add_tag.call this, newtag, (tag) ->
        @emit 'new', tag
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
        @level = opts.level ? 0
        @builder = opts.builder # inheritence
        @pending = [] # no open child tag
        @parent = @builder
        @closed = false
        @writable = true
        @hidden = no
        @isempty = yes
        @content = ""
        @children children, opts
        @$tag = sync_tag
        @tag = new_tag

    emit: =>
        if @builder?.closed is yes and @parent?.closed is yes
            @builder.emit arguments...
        else super

    attr: (key, value) =>
        if typeof key is 'string'
            if not value? and ((attr = @builder?.query 'attr', this, key))?
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
        if not @closed or @closed is 'pending' or @closed is 'approving'
            if @pending.length
                @closed = 'pending'
            else if @closed isnt 'approving' # don't ask twice
                @closed = 'approving'
                close_tag = =>
                    if @isempty
                        @closed = 'self'
                    else
                        @closed = yes
                    @emit 'close', this
                    @emit 'end'
                    @writable = false
                if @builder?
                    @builder.approve('end', this, close_tag)
                else
                    close_tag(this, this)
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
                ">#{@content}</#{@name}>" # FIXME children ?

    add: (rawtag, callback) =>
        tag = @builder?.query 'tag', this, rawtag
        tag = rawtag unless tag? or @builder?
        unless tag?
            callback?.call(this)
            return this
        # TODO query result validation
        add_tag.call(this, tag, callback)
        this

    replace: (tag) =>
        # FIXME should happen smthing smart?
        # should both instances become one? when yes, how?
        @emit 'replace', this, tag
        this

    remove: () =>
        @closed = 'removed' unless @closed
        @emit 'remove', this
        this



class Builder extends EventEmitter
    constructor: (@opts = {}) ->
        # values
        @builder = this
        @pending = [] # no open child tag
        @checkers = {} # all the middlewares that have to approve a new tag
        # states
        @closed = no
        # defaults
        @opts.pretty ?= off
        @level = @opts.level ? -1
        # api
        @Tag = Tag
        @tag = new_tag
        @$tag = sync_tag

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
        else if type is 'tag'
            key # this should be a tag

    register: (type, checker) ->
        unless type is 'new' or type is 'end'
            throw new Error "only type 'new' or 'end' allowed."
        @checkers[type] ?= []
        @checkers[type].push checker

    approve: (type, parent, tag, callback) ->
        checkers = @checkers[type]?.slice?() ? []

        if type is 'new'
            next = (tag) ->
                checker = checkers.shift() ? callback
                checker(parent, tag, next)

        else if type is 'end'
            [callback, tag] = [tag, parent] # shift arguments
            next = (tag) ->
                checker = checkers.shift() ? callback
                checker(tag, next)
        else
            throw new Error "type '#{type}' not supported."
        # start
        next(tag)

# exports

module.exports = { Tag, Builder }



