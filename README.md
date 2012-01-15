
# async XML Generator

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

### Tag(name, [attrs, [children, [opts]]])

```javascript
tag = new asyncxml.Tag("xml", {version:"1.0"}, function() { … }, opts)
```
 * `name` the [nodeName](https://developer.mozilla.org/en/DOM:element.nodeName)
 * `attrs` an object that contains all tag attributes
 * `children` a function representing the children scope of the tag (see `Tag::children` for more)
 * `opts` some internal options

Normally you don't need to instantiate this, because you should use `Tag::tag` and `Builder::tag` instead.


### tag.tag(name, [attrs, [children, [opts]]])

```javascript
tag.tag("name", {attrs:null}, function() { … })
```
Same api as `Tag`.
__info__ tag is not closed.

Emits a `new` and `add` Event.


### tag.$tag(name, [attrs, [children, [opts]]])

```javascript
tag.$tag("sync", function() { … })
```
Same api as `Tag`, with one difference: `tag.end()` is called right after the children scope (even when no children scope is applied).

Emits a `new`, `add` and `end` Event (end is emitted after the children scope).


### tag.toString()

```javascript
tag.$tag("tag", "content").toString()
(new a.Tag("tag", "content")).tag("troll").up().end().toString()
// both => '<tag>content</tag>'
```
This returns the String representation of the tag when its closed.
It only contains text content, no children tags, because tags are garbage collected when their not in use anymore.


### tag.children(childrenscope)

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


### tag.up([opts])

```javascript
tag.up()
tag.up({end:false}) // don't close tag
```
Useful for chaining, because it returns the parent tag.
It closes the tag by default unless `opts.end` is set to false.

Can emit an `end` Event.


### tag.add(newtag)

```javascript
other = new asyncxml.Tag("other")
tag.add(other)
```
Append a new Tag.

Adapter specific objects can be passed too.
For example if you use the [jQuery Adapter](https://github.com/dodo/node-dt-jquery) you can pass a jQuery Object as parameter.

Emits an `add` Event.


### tag.replace(newtag)

```javascript
other = new asyncxml.Tag("other")
tag.replace(other)
```
Replace a tag with another one.
__todo__ merge tag instances on data model level

Emits a `replace` Event.


### tag.remove()

```javascript
tag.remove()
```
Remove a tag immediately.
The tag gets automatically closed.

Emits a `remove` Event.


### tag.attr([key, [value]])

```javascript
tag.attr() // results in an js object containing all tag attributes
tag.attr("id") // results in the value of attribute "id"
tag.attr("id", 3) // set attribute "id" to 3 and returns the tag instance for chaining
tag.attr({id:4}) // set many attributes at once
```
Set or Get tag attributes.

When using an adapter getting an attribute results in a value provided by the adapter.
e.g. if you use the [jQuery Adapter](https://github.com/dodo/node-dt-jquery) the resulting value is the return value of [jQuery.attr](http://api.jquery.com/attr/).

Emits an `attr` Event.


### tag.removeAttr(key)

```javascript
tag.removeAttr("id")
```
Remove a specific attribute by key.

Emits an `attr:remove` Event.


### tag.text([content])

```javascript
tag.text() // get text of a tag
tag.text("content") // set text
```
Set or Get tag text content.

Emits a `text` and `data` Event.

When using an adapter getting text results in the content provided by the adapter.
e.g. if you use the [jQuery Adapter](https://github.com/dodo/node-dt-jquery) the resulting text is the return value of [jQuery.text](http://api.jquery.com/text/).


### tag.raw(html)

```javascript
tag.raw("<div>notfunny</div>")
```
Insert raw html content into a tag.

Emits a `raw` and `data` Event.


### tag.write(data, [opts])

```javascript
fs = require('fs')
fs.createReadStream(filename).pipe(tag)
```
Write tag data.
Useful to pipe file content into a tag (as text).
(dunno what happens if you pipe binary through)

Emits a `data` Event.


### tag.hide()

```javascript
tag.hide()
```
Hide a tag.
When a tag is hidden, `data` events are omitted.

Emits a `hide` Event.


### tag.show()

```javascript
tag.show()
```
Show a tag.
Reverses the effect from `Tag::hide`.

Emits a `show` Event.


### tag.end()

```javascript
tag.end()
```
Closes a tag.
The `end` event will only appear when all children tags are closed.
The `close` event gets triggered when the closing part of the tag (`</tag>`) gets emitted.

Emits an `end` and a `close` Event.





todo


[![Build Status](https://secure.travis-ci.org/dodo/node-asyncxml.png)](http://travis-ci.org/dodo/node-asyncxml)
