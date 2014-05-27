path = require 'path'
{ createReadStream } = require 'fs'
{ Tag, Builder } = require '../asyncxml'
streamify = require 'dt-stream'

# the problem is that at the point when an array is printed (eg, in an error) it
# can differ from its original state, because something async happened after the
# test is done (and before the error is printed).
copyarr = (arr) -> Array.prototype.slice.call arr


module.exports =

    simple: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            '</test>'
        ]
        xml.tag('test').end()
        xml.end()


    'escape': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            '&lt;&quot;lind&quot;&amp;wurm&gt;'
            '</test>'
        ]
        test = xml.tag('test')
        test.text '<"lind"&wurm>', escape:yes
        test.end()
        xml.end()


    chain: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            '<items>'
            '<item value="a">'
            '</item>'
            '<item value="b">'
            '</item>'
            '<item value="c">'
            '</item>'
            '</items>'
            '</test>'
        ]
        xml
            .tag('test')
                .tag('items')
                    .tag('item', value:'a').up()
                    .tag('item', value:'b').up()
                    .tag('item', value:'c').up()
                .up()  # test
            .up()  # items
        .end() # xml


    'self closing': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            '<items>'
            '<item value="a"/>'
            '<item value="b"/>'
            '<item value="c"/>'
            '</items>'
            '</test>'
        ]
        xml.register 'end', (tag, next) ->
            tag.isempty = yes if tag.isselfclosing
            next(tag)
        xml
            .tag('test')
                .tag('items')
                    .tag('item', value:'a').up()
                    .tag('item', value:'b').up()
                    .tag('item', value:'c').up()
                .up()  # test
            .up()  # items
        .end() # xml


    attr: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            '<item value="b" a=1 b=2 c=3>'
            '</item>'
            '</test>'
        ]
        test = xml.tag('test')
        item = test.tag('item', value:'a')
        æ.equal item.attr('value'), "a"
        item.attr(a:1, b:2, c:3)
            .attr('value', "b")
        æ.equal item.attr('value'), "b"
        æ.equal item.attr('non-existant'), undefined
        item.up().up().end()


    toString: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            'rofl'
            '<item value="a" a=1 b=2 c=3>'
            '</item>'
            'lol'
            '</test>'
        ]
        test = xml.tag('test')
        test.text("rofl")
        æ.equal test.toString(), '<test>rofl'
        item = test.tag('item', value:'a', a:1, b:2, c:3)
        test.text("lol")
        item.up().up().end()
        æ.equal test.toString(), '<test>lol</test>'
        æ.equal item.toString(), '<item value="a" a=1 b=2 c=3></item>'


    text: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            'in here'
            '</test>'
        ]
        test = xml.tag('test')
        test.text "in here"
        æ.equal test.text(), "in here"
        test.end()
        xml.end()


    'sequencial text': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            'in'
            ' '
            'here'
            '</test>'
        ]
        test = xml.tag('test')
        test.text "in",   append:on
        test.text " ",    append:on
        test.text "here", append:on
        æ.equal test.text(), "in here"
        test.end()
        xml.end()


    'advanced text ordering': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<text>'
            'this is some '
            '<a href="#">'
            'random'
            '</a>'
            ' text'
            '</text>'
        ]
        test = xml.tag('text')
        test.text "this is some ", append:on
        test.tag('a', href:'#', "random").end()
        test.text " text", append:on
        æ.equal test.text(), "this is some  text" # TODO should this contain children text as well?
        test.end()
        xml.end()


    attributes: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test a=1 b="b" c d=true>'
            '</test>'
        ]
        xml.tag('test', a:1, b:'b', c:null, d:true).end()
        xml.end()


    empty: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<test>'
            '</test>'
            '<p>'
            'content'
            '</p>'
            '<p>'
            'end'
            '</p>'
        ]

        xml.tag('test').end()
        xml.$tag('p', "content")
        p = xml.tag('p', "end")
        p.end()
        xml.end()


    'default pretty': (æ) ->
        xml = streamify new Builder pretty:on
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<apple>\n'
            '  <wurm>\n'
            '  </wurm>\n'
            '</apple>\n'
        ]
        apple = xml.tag('apple')
        apple.tag('wurm').end()
        apple.end()
        xml.end()


    'opts pretty': (æ) ->
        xml = streamify new Builder pretty:"→ → →"
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<product>\n'
            '→ → →<metadata>\n'
            '→ → →→ → →<count value=4>\n'
            '→ → →→ → →</count>\n'
            '→ → →</metadata>\n'
            '</product>\n'
        ]
        product = xml.tag('product')
        æ.equal product.level, 0
        metadata = product.tag('metadata')
        æ.equal metadata.level, 1
        product.end()
        count = metadata.tag('count', value:4)
        æ.equal count.level, 2
        count.end()
        metadata.end()
        xml.end()


    children: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<apple>'
            '<wurm color="red">'
            '<seed>'
            '</seed>'
            '</wurm>'
            '</apple>'
        ]
        apple = xml.tag 'apple', ->
            wurm = @tag 'wurm', color:'red'
            wurm.children ->
                @tag('seed').end()
                @end()
            @end()
        xml.end()


    'async children': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<apple>'
            '<wurm color="red">'
            '<seed>'
            '<is dead=true>'
            '</is>'
            '</seed>'
            '</wurm>'
            '</apple>'
        ]

        seed = null
        apple = xml.tag 'apple', ->
            @$tag 'wurm', color:'red', ->
                seed = @tag('seed')
            @end()

        setTimeout ( ->
            æ.notEqual seed, null
            return unless seed
            seed.tag('is', dead:yes).end()
            seed.end()
        ), 3

        xml.end()


    'pause/resume': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<apple>'
            '<wurm color="red">'
            '<seed>'
            '<is dead=true>'
            '</is>'
            '</seed>'
            '</wurm>'
            '</apple>'
        ]

        seed = null
        apple = xml.tag 'apple', ->
            xml.stream.pause()
            @$tag 'wurm', color:'red', ->
                seed = @tag('seed')
            @end()

        setTimeout ( ->
            æ.notEqual seed, null
            return unless seed
            seed.tag('is', dead:yes).end()
            seed.end()
            xml.stream.resume()
        ), 3

        xml.end()


    complex: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<global>'
            '<test version=3 alt="info" border=0>'
            '<top center=true>'
            '</top>'
            '<foo bar="moo" border=0>'
            '<first>'
            '</first>'
            '<bar x=2>'
            '</bar>'
            '<center args="true">'
            '</center>'
            '<last>'
            '</last>'
            '<xxx ccc=true>'
            '<pok>'
            '</pok>'
            '<asd>'
            '</asd>'
            '<happy dodo>'
            '</happy>'
            '</xxx>'
            '</foo>'
            '</test>'
            '</global>'
        ]

        global = xml.tag('global')
        test = global.tag('test', version:3, alt:"info", border:0)
        test.tag('top', center:yes).end()
        foo = test.tag('foo', bar:'moo', border:0)

        global.end()
        xml.end()

        foo.tag('first').end()
        bar = foo.tag('bar', x:2)
        foo.tag('center', args:"true").end()
        foo.tag('last').end()
        xxx = foo.tag('xxx', ccc:yes)

        bar.end()
        xxx.tag('pok').end()
        foo.end()

        xxx.tag('asd').end()

        xxx.tag('happy', dodo:null).end()
        test.end()

        xxx.end()


    delayed: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<grass>'
            '<dog>'
            '</dog>'
            '<cat>'
            '</cat>'
            '</grass>'
        ]
        dog = null
        grass = xml.tag('grass')
        setTimeout ( ->
            dog = grass.tag('dog')
        ), 2
        setTimeout ( ->
            grass.tag('cat').end()
            dog.end()
        ), 3
        setTimeout ( ->
            xml.end()
            grass.end()
        ),4


    pipe: (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<file>'
            'hello world\n'
            '</file>'
        ]

        file = xml.tag('file')
        stream = createReadStream path.join(__dirname, "..", "filename")
        stream.pipe(file)
        xml.end()

    'sync call order': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<apple>'
            '<wurm>'
            '<seed>'
            '</seed>'
            '</wurm>'
            '</apple>'
        ]
        counter = 0
        apple = xml.$tag 'apple', ->
            æ.equal counter, 0
            counter++
            wurm = @$tag 'wurm', ->
                æ.equal counter, 1
                counter++
                @tag('seed').end()
                æ.equal counter, 2
            counter++
            æ.equal counter, 3
        counter++
        æ.equal counter, 4
        xml.end()
        counter++
        æ.equal counter, 5


    'api events': (æ) ->
        xml = new Builder
        xml.on 'end', ->
            æ.deepEqual copyarr(results.add),   ['add',   "root", "childA", "childB", "childC"]
            æ.deepEqual copyarr(results.close), ['close', "childB", "childC", "root", "childA"]
            æ.done()

        results = add:['add'], close:['close']

        xml.on 'add', (par, el) ->
            results.add.push   el.name unless el is el.builder
        xml.on 'close', (el) ->
            results.close.push el.name unless el is el.builder

        root = xml.tag('root')
        c = root.tag('childA')
        c.tag('childB').end()
        c.$tag('childC')
        root.end()
        c.end()
        xml.end()


    'after closed': (æ) ->
        xml = new Builder
        last = null
        xml.on 'end', -> results.end++

        results = add:['add'], close:['close'], end:0

        done = ->
            æ.deepEqual copyarr(results.add),   ['add',   "first", "middle", "last"]
            #console.log copyarr results.close, results.close.length
            æ.deepEqual copyarr(results.close), ['close', "first", "last", "middle"]
#             for x in ['close', "first", "last", "middle"]
#                 æ.equal results.close.shift(), x

            æ.done()

        xml.on 'add', (par, el) ->
            results.add.push   el.name unless el is el.builder
        xml.on 'close', (el) ->
            results.close.push el.name unless el is el.builder

        first = xml.tag('first')
        first.end()
        xml.end()

        middle = first.$tag 'middle', ->
            # should be allready closed here
            æ.equal results.end, 1

            @$tag('last', "content")
            @on('end', done)


    inception: (æ) ->
        xml = new Builder
        xml.on 'end', ->
            æ.deepEqual copyarr(results.add),   ['add',   "root", "childA", "childB", "childC"]
            æ.deepEqual copyarr(results.close), ['close', "root", "childA", "childC", "childB"]
            æ.done()

        results = add:['add'], close:['close']

        xml.on 'add', (par, el) ->
            results.add.push   el.name unless el is el.builder
        xml.on 'close', (el) ->
            results.close.push el.name unless el is el.builder

        sub = new Builder
        root = xml.tag('root').add(sub).end()
        sub.$tag('childA')
        sub.tag('childB').tag('childC').up().end()
        sub.end()
        xml.end()


    'builder::add': (æ) ->
        xml = new Builder
        xml.on 'end', ->
            æ.deepEqual copyarr(results.add),   ['add',   "root", "childA"]
            æ.deepEqual copyarr(results.close), ['close', "root", "childA"]
            æ.done()

        results = add:['add'], close:['close']

        xml.on 'add', (par, el) ->
            results.add.push   el.name unless el is el.builder
        xml.on 'close', (el) ->
            results.close.push el.name unless el is el.builder

        xml.tag('root').end()
        xml.add new Tag "childA", -> @end()
        xml.end()


    'streamified builder::add': (æ) ->
        xml = streamify new Builder
        xml.stream.on 'data', (tag) -> æ.equal results.shift(), tag
        xml.stream.on 'end', ->
            æ.equal 0, results.length
            æ.done()
        results = [
            '<root>'
            '</root>'
            '<childA>'
            '</childA>'
        ]

        xml.tag('root').end()
        xml.add new Tag "childA", -> @end()
        xml.end()


    'Tag::replace': (æ) ->
        xml = new Builder
        xml.on 'end', ->
            æ.equal "replaced", (old_replaced and "replaced" or "no replace")
            æ.equal "replaced", (replaced is 1 and "replaced" or "0 replaces")
            æ.equal "no own event", (own_event and "own event" or "no own event")
            æ.equal "no new tag", (new_tag and "new tag" or "no new tag")
            æ.equal "closed old tag", (closed_old and "closed old tag" or "old tag is open")
            æ.equal "closed new tag", (closed_new and "closed new tag" or "new tag is open")
            æ.equal 1, children
            æ.done()
        replaced = 0
        old_replaced = no
        own_event = no
        new_tag = no
        closed_old = no
        closed_new = yes
        children = 0

        old = xml.tag "old"
        xml.on 'replace', -> replaced++
        old.on 'replace', -> old_replaced = yes
        old.on 'own event', -> own_event = yes
        old.on 'end', -> closed_old = yes
        old.on 'add', -> new_tag = yes
        xml.on 'add', -> children++

        tag = new Tag "new"
        tag.on 'end', -> closed_new = yes
        old.replace tag
        tag.emit 'own event'
        tag.$tag("test")

        old.end()
        tag.end()
        xml.end()
