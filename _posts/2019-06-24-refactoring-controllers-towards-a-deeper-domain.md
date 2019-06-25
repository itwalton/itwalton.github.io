---
layout: post
date: 2019-06-24
title: Refactoring Controllers towards a Deeper Domain
header: Refactoring Controllers towards a Deeper Domain
description: Separate the NoSQL persistence layer from the business logic following DDD principles.
---

Over the last few years, I've been on a few projects built in the "modern architecture", where services are compartmentalized into small, deployable units called microservices. Typically, the services start small, based around some vague idea of our domain's bounded context and scale indefinitely as time passes. Concepts from [Eric Evan's Domain Driven Design](http://domainlanguage.com/ddd/) are passed around the design table, and models are built around the organization's Ubiquitous Language. But sooner or later requirements shuffle, deadlines loom, and the succinct domain of yester-month is replaced with a frankenstein of fat controllers calling handfuls of one-off methods in dozens of interfaces. This will the the first part of a series of salvaging order from the entropy that is production applications.

Imagine your building a Node/Express/Mongo app to sell Widgets for your hot new company. At first, life is easy. You establish a connection to your secure Mongo daemon running conveniently on localhost and send the user your requested product:

~~~ javascript
  const mongoClient = MongoClient.connect({ url: `mongodb://${mongoUrl}` })
  const widgetCollection = mongoClient.db('widget')

  ...

  widget = await widgetCollection.findOne({ id: req.id })
  res.send({ widget })
~~~

This example is trivial, and woefully insecure, but it works! Until Karen from Procurement wants you to return an different product if the widget is out of stock.

~~~ javascript
  const widget = await widgetCollection.findOne({ id: req.id })
  const inventory = await inventoryCollection.findOne({ widget: req.id })
  if (inventory.inStock) return res.send({ widget })

  res.send({ widget: { name: 'PLACEHOLDER' } })
~~~

Not great, but it still works I guess. Then Ted swings by and says the executive team wants to go global. Such synergy. But they're going to make it easy for you. You just need to use the request headers to glean relative geographical data, query your 10-year old Distribution service to find the closest DC and use THAT to find the inventory record so we can send Karen's placeholder widget.

~~~ javascript
  const closestDistributionCenter = await geoservice.find({ location: req.headers.location })
  if (closestDistributionCenter.distance > req.body.maxDistanceInKm) return res.send({ widget: null })

  const inventory = await inventoryCollection.findOne({ widget: req.id, dc: closestDistributionCenter.id })
  if (inventory.inStock) {
    const widget = await widgetCollection.findOne({ id: req.id })
    return res.send({ widget })
  }

  res.send({ widget: { name: 'PLACEHOLDER' } })
~~~

Hopefully it's clear that I'm cutting corners for the sake of demonstration. It should be clear by now that coupling controllers with persistence with domain logic can cause all sorts of problems, least of which is readability. Rather, domain logic should be buried deep in the application state, surrounded by nuggets of domain vernacular and isolated by where the data comes from and where it needs to go.

There's two clear domain objects, or Entities, in the above example: Widgets and Inventory. We can start by abstracting the mongo bits into Repositories. Repositories should know how to interact with the Infrastructure, our MongoDB, and transform POJOs into Entity instances:

~~~ javascript
  const createWidgetRepository = ({ mongoDb }) => {
    const collection = mongoDb.collection('widget')

    // public interface
    return {
      findById: async (id = '') => {
        const cursor = collection.find({ id })
        if (await cursor.hasNext()) {
          const widget = await cursor.next()
          return new Widget({ id: widget.id, name: widget.name, description: widget.description })
        }

        return null
      }
    }
  }

  const createInventoryRepository = ({ mongoDb }) => {
    const collection = mongoDb.collection('inventory')

    // public interface
    return {
      findByWidgetAtDC: async ({ widget = '', dc = '' }) => {
        const cursor = collection.find({ id })
        if (await cursor.hasNext()) {
          const inventory = await cursor.next()
          return new Inventory({ id: inventory.id, dc: inventory.dc })
        }

        return null
      }
    }
  }

  ...

  const closestDistributionCenter = await geoservice.find({ location: req.headers.location })
  if (closestDistributionCenter.distance > req.body.maxDistanceInKm) return res.send({ widget: null })

  const inventory = await inventoryRepo.findByWidgetAtDC({ widget: req.id, dc: closestDistributionCenter.id })
  if (inventory.isWidgetInStock()) {
    const widget = await widgetRepo.findById(req.id)
    return res.send({ widget })
  }

  res.send({ widget: { name: 'PLACEHOLDER' } })
~~~

Haven't changed much, but already our controller is cleaner. We're not coupled to Mongo anymore, and it's a bit easier to read what's going on. But the controller still knows too much - specifically, how our inventory records are structured and how to find the distribution center. Service objects are a great way to abstract domain logic spanning multiple Entities.

~~~ javascript
  const createInventoryService = ({ geoservice, inventoryRepo }) => ({
    isWidgetInStockWithinKilometers: async ({ widget, location, maxDistance = 50 }) => {
      const closestDistributionCenter = await geoservice.find({ location })
      if (closestDistributionCenter.distance > maxDistance) return false

      const inventory = await inventoryRepo.findByWidgetWithAtDC({ widget, dc: closestDistributionCenter.id })
      return inventory.isWidgetInStock()
    }
  })

  ...

  const isWidgetInStock = await inventoryService.isWidgetInStockWithinKilometers({
    widget: req.id,
    location: req.headers.location,
    maxDistance: req.body.maxDistanceInKm
  })

  const widget = isWidgetInStock ? await widgetRepo.findById(req.id) : { name: 'PLACEHOLDER' }

  res.send({ widget })
~~~

We've now created two Repositories to transact with the persistence layer and return domain objects, a Service to handle the interaction between domain objects and a smaller, more legible controller with methods defined around the Ubiquitous Language and less coupled to the various components of our application.

I hope you enjoyed the article! Still shaking off the rust. Look for more articles coming soon! If you have any questions/comments/concerns, as always, feel free to follow me on Twitter.
