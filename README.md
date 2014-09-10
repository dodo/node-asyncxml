
# [async XML Generator](https://github.com/dodo/node-asyncxml)

> performance? foock it! i'm faster than that.

async xml builder and generator

nukular engine of [Δt](http://dodo.github.com/node-dynamictemplate/)

Runs on server and browser side (same code).

## install

    npm install asyncxml

## usage

```javascript
asyncxml = require('asyncxml')
xml = new asyncxml.Builder({pretty:true})
xml.on('data', function (chunk) {
    console.log(chunk);
})
// build some xml
xml.tag("xml", {version:"1.0"})
        .tag("list")
            .tag("entry", function () {
                this.attr('id', 1)
            }).up()
            .tag("entry", {id:2}, "foo").up()
        .up()
    .up()
.end()
```

```coffeescript
# this would result in the same xml
xml.tag "xml", version:"1.0", ->
    @$tag "list", ->
        @$tag "entry", ->
            @attr('id', 1)
        @$tag "entry", id:2, "foo"
    @up().end()
```

```xml
<!-- stdout -->
<xml version="1.0">
  <list>
    <entry id=1/>
    <entry id=2>
    foo
    </entry>
  </list>
</xml>

```

## api

### Builder([opts])

```javascript
xml = new asyncxml.Builder({pretty:true})
```
 * `opts.pretty` switch to toggle pretty printing of the xml output
 * `opts.level` start indention level of xml (starting with `-1`) when pretty is on

Use this to build and grow a XML forest.

The Builder provides a single environment for many tags and an API for Adapters to interact with the tag events.

#### xml.tag(name, [attrs, [children, [opts]]])

```javascript
tag.tag("xml", {version:"1.0"}, function() { … })
```
Same as `Tag::tag`.


#### xml.$tag(name, [attrs, [children, [opts]]])

```javascript
tag.$tag("xml", {version:"1.0"}, function() { … })
```
Same as `Tag::$tag`.


#### xml.show()

```javascript
xml.show()
```
Same as `Tag::show`.


#### xml.hide()

```javascript
xml.hide()
```
Same as `Tag::hide`.


#### xml.remove([opts])

```javascript
xml.remove({soft:true})
```
Same as `Tag::remove`.


#### xml.ready(callback)

```javascript
xml.ready(function () {
  console.log("builder is done.")
})
```
Instead of `Tag::ready` it waits for the `end` event,


#### xml.end()

```javascript
xml.end()
```
Same as `Tag::end` but without a `close` event.


#### xml.register(type, checkfn)

```javascript
xml.register('new', function (parent, tag, next) {
    // this gets called _before_ every new tag gets announced ('new' and 'add' event)
    next(tag) // call next with the new tag to approve that the new tag can be announced
})
xml.register('end', function (tag, next) {
    // this gets called _before_ every gets closed
    next(tag) // call next with the closing tag to approve that the tag can be closed
})
```
This is a plugin API method.

There are only 2 types: `["new", "end"]`.

The `checkfn` function of type `new` must get 3 parameters: `(parent, tag, next)`.

The `checkfn` function of type `end` must get 2 parameters: `(tag, next)`.

The [Δt Compiler](http://dodo.github.com/node-dt-compiler/) uses this API to create new tags before others.


#### xml.approve(type, parent, tag, callback)

This is an internal API method to invoke a `checkfn` list registered with `Builder::register` by plugins.


#### xml.query(type, tag, key)

```javascript
tag.text()
tag.attr('id')
tag.add(adapter_specific_object)
```
This is a adapter API method.

Every time a text, an attribute or a tag is requested the tag will ask the builder for the values. A adapter has now the opportunity to override the `query` method of the builder instance to provide a specialised query method.

The [jQuery Adapter](https://github.com/dodo/node-dt-jquery) for example uses it to provide the values right out of the DOM (eg for type text it returns the value of [jQuery.text](http://api.jquery.com/text/)).


---

### Tag(name, [attrs, [children, [opts]]])

```javascript
tag = new asyncxml.Tag("xml", {version:"1.0"}, function() { … }, opts)
```
 * `name` the [nodeName](https://developer.mozilla.org/en/DOM:element.nodeName)
 * `attrs` an object that contains all tag attributes
 * `children` a function representing the children scope of the tag (see `Tag::children` for more)
 * `opts` some internal options

Normally you don't need to instantiate this, because you should use `Tag::tag` and `Builder::tag` instead.


#### tag.tag(name, [attrs, [children, [opts]]])

```javascript
tag.tag("name", {attrs:null}, function () { … })
// these work as well:
tag.tag("name", {attrs:null}, "content")
tag.tag("name", function () {…})
tag.tag("name", "content")
```
Same api as `Tag`.
__info__ tag is not closed.

Emits a `new` and `add` Event.


#### tag.$tag(name, [attrs, [children, [opts]]])

```javascript
tag.$tag("sync", function() { … })
```
Same api as `Tag`, with one difference: `tag.end()` is called right after the children scope (even when no children scope is applied).

Emits a `new`, `add` and `end` Event (end is emitted after the children scope).


#### tag.toString()

```javascript
tag.$tag("tag", "content").toString()
(new a.Tag("tag", "content")).tag("troll").up().end().toString()
// both => '<tag>content</tag>'
```
This returns the String representation of the tag when its closed.

It only contains text content, no children tags, because tags are garbage collected when their not in use anymore.


#### tag.children(childrenscope)

```javascript
tag.children(function () {
    this.attr({id:2})
    this.$tag("quote", "trololo") // same as this.$tag("quote").children("trololo")
})
tag.children("content") // same as tag.text("content")
```
This applies a children scope on a tag.

The tag instance directly accessible via `this`.

The children parameter of `Tag::tag` is passed to this method.

Emits whatever event is emitted inside the children scope (of course).


#### tag.root()

```javascript
tag.root()
```

Returns the root parent (recursive).

Doesn't close the tag nor its parents.

#### tag.up([opts])

```javascript
tag.up()
tag.up({end:false}) // don't close tag
```
Useful for chaining, because it returns the parent tag.

It closes the tag by default unless `opts.end` is set to false.

Can emit an `end` Event.


#### tag.add(newtag)

```javascript
other = new asyncxml.Tag("other")
tag.add(other)
```
Append a new Tag.

Adapter specific objects can be passed too.

For example if you use the [jQuery Adapter](https://github.com/dodo/node-dt-jquery) you can pass a jQuery Object as parameter.

Emits an `add` Event.


#### tag.replace(newtag)

```javascript
other = new asyncxml.Tag("other")
tag.replace(other)
```
Replace a tag with another one.

__todo__ merge tag instances on data model level

Emits a `replace` Event.


#### tag.remove()

```javascript
tag.remove()
```
Remove a tag immediately.
The tag gets automatically closed.

Emits a `remove` Event.


#### tag.attr([key, [value]])

```javascript
tag.attr() // results in an js object containing all tag attributes
tag.attr("id") // results in the value of attribute "id"
tag.attr("id", 3) // set attribute "id" to 3 and returns the tag instance for chaining
tag.attr({id:4}) // set many attributes at once
```
Set or Get tag attributes.

When using an adapter getting an attribute results in a value provided by the adapter.

When getting a value the results can be interpreted as follow:

* `undefined` the tag doesn't have this attribute
* `null` the attributes doesn't have a value
* everything else is a the value of the attribute

e.g. if you use the [jQuery Adapter](https://github.com/dodo/node-dt-jquery) the resulting value is the return value of [jQuery.attr](http://api.jquery.com/attr/).

Emits an `attr` Event.


#### tag.text([content, [opts]])

```javascript
tag.text() // get text of a tag
tag.text("content") // set text
```
Set or Get tag text content.

Options:
* `escape`
* `append`

Emits a `text` and `data` Event.

When using an adapter getting text results in the content provided by the adapter.

e.g. if you use the [jQuery Adapter](https://github.com/dodo/node-dt-jquery) the resulting text is the return value of [jQuery.text](http://api.jquery.com/text/).


#### tag.raw(html, [opts])

```javascript
tag.raw("<div>notfunny</div>")
```
Insert raw html content into a tag.


Emits a `raw` and `data` Event.


#### tag.write(data, [opts])

```javascript
fs = require('fs')
fs.createReadStream(filename).pipe(tag)
```
Write tag data.

Useful to pipe file content into a tag (as text).
(dunno what happens if you pipe binary through)

Options:
* `escape`

Emits a `data` Event.


#### tag.hide()

```javascript
tag.hide()
```
Hide a tag.

When a tag is hidden, `data` events are omitted.

Emits a `hide` Event.


#### tag.show()

```javascript
tag.show()
```
Show a tag.

Reverses the effect from `Tag::hide`.

Emits a `show` Event.


#### tag.end()

```javascript
tag.end()
```
Closes a tag.

The `end` event will only appear when all children tags are closed.

The `close` event gets triggered when the closing part of the tag (`</tag>`) gets emitted.

Emits an `end` and a `close` Event.

---

## events

Some events have special behavior when it comes to where they can be received.

Most events travel up the XML tree, some can be only received on their parents.

### global

```javascript
['add', 'attr', 'text', 'raw', 'data', 'show', 'hide', 'remove', 'replace', 'close']
````
These events can be received from every single tag.

When you listen on a *specific tag* you get these events from the tag you are listening on and from all the children tags (recursive).

When you listen on a *builder instance* you get all events from all tags.

### local

```javascript
['new', 'end']
```
These events can be received from every single tag.

When you listen for `new` on a *specific tag* you get 'new' events from only the tag you are listening on and from all its direct children (only 1 level deep).

When you listen for `new` on a *builder instance* you get 'new' events for all the tags that are created direclty on the builder.

When you listen for `end` on a *specific tag* you get the 'end' event only from the tag you are listening on.

When you listen for `end` on a *builder instance* you get the 'end' event when the last tag is closed.


## partials

It's recursive! just add a builder instance to a tag:
```javascript
xml = new Builder
sub = new Builder
root = xml.tag('root').add(sub).end()
```



[![Build Status](https://secure.travis-ci.org/dodo/node-asyncxml.png)](http://travis-ci.org/dodo/node-asyncxml)
