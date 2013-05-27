class PushServices
    services: {}

    addService: (protocol, service) ->
        @services[protocol] = service

    getService: (protocol) ->
        return @services[protocol]

    push: (subscriber, subOptions, payload, cb) ->
        subscriber.get (info) =>
            if info then @services[info.proto]?.push(subscriber, subOptions, payload)
            cb() if cb

    servicesWithQueuedMessages: ->
        return (proto for proto, service of @services when not service.allMessagesPushed())

exports.PushServices = PushServices
