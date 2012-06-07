{ isArray } = Array


indent = ({level, pretty}) ->
    return "" if not pretty or level is 0
    pretty = "  " if pretty is on
    return pretty


breakline = ({level, pretty}, data) ->
    return data unless pretty
    if data?[data?.length-1] is "\n"
        return data
    else
        return "#{data}\n"


prettify = (el, data) ->
    unless el?.pretty
        return data
    else
        return "#{indent el}#{breakline el, data}"


new_attrs = (attrs = {}) ->
    strattrs = for k, v of attrs
        if v?
            v = "\"#{v}\"" unless typeof v is 'number'
            "#{k}=#{v}"
        else "#{k}"
    strattrs.unshift '' if strattrs.length
    strattrs.join ' '


safe = (text) ->
    String(text)
        .replace(/&(?!\w+;)/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')


module.exports = { prettify, indent, new_attrs, safe }
