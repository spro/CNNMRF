transfer_CNNMRF_wrapper = require 'transfer_CNNMRF_wrapper'
somata = require '../../somata-lua/somata'

function keys(object)
    local ks = {}
    for k, v in pairs(object) do
        table.insert(ks, k)
    end
    return ks
end

function values(object)
    local vs = {}
    for k, v in pairs(object) do
        table.insert(vs, v)
    end
    return vs
end

function extend(object, with)
    print("extending", object, "with", with)
    for k, v in pairs(with) do
        if object[k] == nil then
            object[k] = v
        end
    end
    return object
end

function map(f, a)
    a_ = {}
    for x, i in pairs(a) do
        print(string.format("x is %s and i is %s", x, i))
        table.insert(a_, f(i))
    end
    return a_
end

function layerToN(l)
    return tonumber(string.sub(l, 2, 3))
end

default_options = {
    size=600,
    style_layers={l12w=0.005, l21w=0.005},
    resolutions={100, 100, 100},
    content_weight=500,
}

function makeParams(content, style, options, job_id)
    if options == nil then options = default_options
    else options = extend(options, default_options) end

    -- Hack to get sorted layers as CNNMRF seems to die without
    local mrf_layers = map(layerToN, keys(options.style_layers))
    table.sort(mrf_layers)
    local mrf_weights = {}
    for i, l in pairs(mrf_layers) do
        layer_key = 'l' .. l .. 'w'
        mrf_weights[i] = options.style_layers[layer_key]
    end

    function onProgress(update)
        print("[onProgress]", job_id, update)
        render_service:publish('progress:' .. job_id, update)
    end

    return {
        content, style, 'image',
        options.size, #options.resolutions, options.resolutions,
        mrf_layers, mrf_weights, {3, 3, 3},
        0, 0,
        {2, 2, 2}, {2, 2, 2}, {0, 0, 0},
        {23}, options.content_weight, 1e-3,
        'speed', 32, 2, 'cudnn',
        onProgress
    }
end

render_service = somata.Service.create('style:render', {
    render=function(job_id, content, style, options, cb)
        function doGo()
            transfer_CNNMRF_wrapper.run_test(unpack(makeParams(content, style, options, job_id)))
            cb()
        end
        render_service.loop:add_once(500, doGo)
    end
}, {heartbeat=20 * 1000})

render_service:register()
