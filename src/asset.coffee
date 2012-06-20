#
# The Asset class is responsible for managing all aspects of the 
# decoding pipeline from source to decoder.  You can use the Asset
# class to inspect information about an audio file, such as its 
# format, metadata, and duration, as well as actually decode the
# file to linear PCM raw audio data.
#

class Asset extends EventEmitter
    window.Asset = Asset
    
    constructor: (@source) ->
        @buffered = 0
        @duration = null
        @format = null
        @metadata = null
        @active = false
        @demuxer = null
        @decoder = null
                
        @source.once 'data', @probe
        @source.on 'error', (err) =>
            @emit 'error', err
            @stop()
            
        @source.on 'progress', (@buffered) =>
            @emit 'buffer', @buffered
            
    @fromURL: (url) ->
        source = new HTTPSource(url)
        return new Asset(source)

    @fromFile: (file) ->
        source = new FileSource(file)
        return new Asset(source)
        
    start: ->
        return if @active
        
        @active = true
        @source.start()
        
    stop: ->
        return unless @active
        
        @active = false
        @source.pause()
        
    get: (event, callback) ->
        return unless event in ['format', 'duration', 'metadata']
        
        if this[event]?
            callback(this[event])
        else
            @once event, (value) =>
                @stop()
                callback(value)
            
            @start()
    
    probe: (chunk) =>
        return unless @active
        
        demuxer = Demuxer.find(chunk)
        if not demuxer
            return @emit 'error', 'A demuxer for this container was not found.'
            
        @demuxer = new demuxer(@source, chunk)
        @demuxer.on 'format', @findDecoder
        
        @demuxer.on 'duration', (@duration) =>
            @emit 'duration', @duration
            
        @demuxer.on 'metadata', (@metadata) =>
            @emit 'metadata', @metadata
            
        @demuxer.on 'error', (err) =>
            @emit 'error', err
            @stop()

    findDecoder: (@format) =>
        return unless @active
        
        @emit 'format', @format
        console.log @format
        
        decoder = Decoder.find(@format.formatID)
        if not decoder
            return @emit 'error', "A decoder for #{@format.formatID} was not found."

        @decoder = new decoder(@demuxer, @format)
        @decoder.on 'data', (buffer) =>
            @emit 'data', buffer
			
        @decoder.on 'end', () =>
            @emit 'end'
            
        @decoder.on 'error', (err) =>
            @emit 'error', err
            @stop()
            
        @emit 'decodeStart'