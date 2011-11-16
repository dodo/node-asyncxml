path = require 'path'
{ createReadStream } = require 'fs'
{ Tag, Builder } = require '../asyncxml'

# the problem is that at the point when an array is printed (eg, in an error) it
# can differ from its original state, because something async happened after the
# test is done (and before the error is printed).
copyarr = (arr) -> Array.prototype.slice.call arr


module.exports =

    simple: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.once 'data', (tag) -> æ.equal "<test/>", tag
        xml.tag('test').end()
        xml.end()

    'escape': (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
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
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<test>'
            '<items>'
            '<item value="a"/>'
            '<item value="b"/>'
            '<item value="c"/>'
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

    attr: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<test>'
            '<item value="b" a=1 b=2 c=3/>'
            '</test>'
        ]
        test = xml.tag('test')
        item = test.tag('item', value:'a')
        æ.equal item.attr('value'), "a"
        item.attr(a:1, b:2, c:3)
            .attr('value', "b")
        æ.equal item.attr('value'), "b"
        item.up().up().end()

    toString: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<test>'
            'rofl'
            'lol'
            '<item value="a" a=1 b=2 c=3/>'
            '</test>'
        ]
        test = xml.tag('test')
        test.text("rofl")
        item = test.tag('item', value:'a', a:1, b:2, c:3)
        test.text("lol")
        item.up().up().end()
        æ.equal test.toString(), '<test>lol</test>'
        æ.equal item.toString(), '<item value="a" a=1 b=2 c=3/>'

    text: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
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


    attributes: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.once 'data', (tag) -> æ.equal "<test a=1 b=\"b\" c d=\"true\"/>", tag
        xml.tag('test', a:1, b:'b', c:null, d:true).end()
        xml.end()


    empty: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<test/>'
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
        xml = new Builder pretty:on
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<apple>\n'
            '  <wurm/>\n'
            '</apple>\n'
        ]
        apple = xml.tag('apple')
        apple.tag('wurm').end()
        apple.end()
        xml.end()


    'opts pretty': (æ) ->
        xml = new Builder pretty:"→ → →"
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<product>\n'
            '→ → →<metadata>\n'
            '→ → →→ → →<count value=4/>\n'
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
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<apple>'
            '<wurm color="red">'
            '<seed/>'
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
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<apple>'
            '<wurm color="red">'
            '<seed>'
            '<is dead="true"/>'
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


    complex: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<global>'
            '<test version=3 alt="info" border=0>'
            '<top center="true"/>'
            '<foo bar="moo" border=0>'
            '<first/>'
            '<bar x=2/>'
            '<center args="true"/>'
            '<last/>'
            '<xxx ccc="true">'
            '<pok/>'
            '<asd/>'
            '<happy dodo/>'
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
        foo.tag('center', args:true).end()
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
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<grass>'
            '<dog/>'
            '<cat/>'
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
        ), 4
        setTimeout ( ->
            grass.end()
            xml.end()
        ),3

    pipe: (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<file>'
            'hello world\n'
            '</file>'
        ]

        file = xml.tag('file')
        stream = createReadStream path.join(__dirname,"..","..","..","filename")
        stream.pipe(file)
        xml.end()

    'sync call order': (æ) ->
        xml = new Builder
        xml.on 'end', æ.done
        xml.on 'data', (tag) -> æ.equal results.shift(), tag
        results = [
            '<apple>'
            '<wurm>'
            '<seed/>'
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
            æ.deepEqual copyarr(results.add),   ['add',   "root", "childA", "childB"]
            æ.deepEqual copyarr(results.close), ['close', "childB", "childA", "root"]
            æ.done()

        results = add:['add'], close:['close']

        xml.on 'add', (el) ->
            results.add.push el.name
        xml.on 'close', (el) ->
            results.close.push el.name

        root = xml.tag('root')
        c = root.tag('childA')
        c.tag('childB').end()
        root.end()
        c.end()
        xml.end()






