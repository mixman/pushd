async = require 'async'
c2dm = require 'c2dm'

class PushServiceC2DM
    tokenFormat: /^[a-zA-Z0-9_-]+$/
    validateToken: (token) ->
        if PushServiceC2DM::tokenFormat.test(token)
            return token

    constructor: (conf, @logger, tokenResolver, @failCallback) ->
        conf.concurrency ?= 10
        conf.keepAlive = true
        @driver = new c2dm.C2DM(conf)
        @driver.login (err, token) =>
            if err then throw Error(err)
            @taskQueue = async.queue((=> @_pushTask.apply(@, arguments)), conf.concurrency)
            for task in @queue
                @taskQueue.push task
        # Queue into an array waiting for C2DM login to complete
        @queue = []
        @taskQueue = null

    push: (subscriber, subOptions, payload) ->
        task:
            subscriber: subscriber,
            subOptions: subOptions,
            payload: payload
        @queue.push task
        if @taskQueue?
            @taskQueue.push task

    _pushTask: (task, done) ->
        task.subscriber.get (info) =>
            note =
                registration_id: info.token
                collapse_key: task.payload.event?.name
            if task.subOptions?.ignore_message isnt true
                if title = task.payload.localizedTitle(info.lang) 
                    note['data.title'] = title
                if message = task.payload.localizedMessage(info.lang) 
                    note['data.message'] = message
            note["data.#{key}"] = value for key, value of task.payload.data
            @driver.send note, (err, msgid) =>
                i = @queue.indedOf(task)
                if i >= 0
                    @queue.splice(i, 1)
                done()
                if err
                    @failCallback()
                    if err in ['InvalidRegistration', 'NotRegistered']
                        # Handle C2DM API feedback about no longer or invalid registrations
                        @logger?.warn("C2DM Automatic unregistration for subscriber #{task.subscriber.id}")
                        task.subscriber.delete()
                    else
                        @logger?.error("C2DM Error #{err} for subscriber #{task.subscriber.id}")

    allMessagesPushed: ->
        return @queue.length is 0

exports.PushServiceC2DM = PushServiceC2DM
