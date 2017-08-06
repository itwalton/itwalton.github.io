---
layout: post
date: 2016-06-30
title: Unit Testing SFCC Controllers
header: Unit Testing SFCC Controllers
description: How to write true unit tests against SFCC's new JavaScript Controllers feature with Jasmine and mock-require.
---

This week we'll walk through how to write true unit tests against DemandWare's new Controller implementation. Not familiar with <a href="https://www.demandware.com/" alt="DemandWare">DemandWare</a>? It's an ecommerce platform that uses server-side JavaScript on top of a CMS/ORM recently <a href="http://www.wsj.com/articles/salesforce-to-buy-e-commerce-platform-demandware-for-2-8-billion-1464781833" alt="Salesforce Acquisition">acquired by Salesforce</a>. If you have spent any sort of time working with DemandWare up until now, you've beaten your head against graphical representations of XML-based route definitions like this:

<p class="row">
  <img class="col-md-6 col-md-offset-3" src="/assets/img/pipeline.png" alt="Pipeline" />
</p>

Members of the DemandWare developer community can breath a collective sigh of relief with the stable release of their new JavaScript Contollers. DemandWare has promoted controllers as a more performant, easier to manage, and exponentially easier to test alternative to XML pipelines. You may have even convinced your PM to let you start migrating the XML pipelines to controllers. Unfortunately, you may have noticed a distinct lack of documentation in XChange around how we might test these controllers.

Let's assume for this walkthrough that you've already started migrating Product.xml pipelines to controllers. Your Product-Show pipeline might look something like this:

~~~ javascript
  var guard = require("controllers/cartridge/scripts/guard.js");
  exports.Show = guard.ensure([ "http", "get" ], function () {
    var template = "util/error",
      templateArgs = {};

    var ProductMgr = require("dw/catalog/ProductMgr"),
      product = ProductMgr.getProduct(request.httpParameterMap.pid.stringValue);

    if(product) {
      template = product.template || "product/product";
      templateArgs["Product"] = product;
    }

    var ISML = require("dw/template/ISML");
    ISML.renderTemplate(template, templateArgs);
  });
~~~

Your controller probably has a lot more noise than this, but at least it's working (as far as we know). Since our goal is to write true unit tests, we should start by identifying individual testable units and build clear seams in our application around these units. The guard service is responsible for applying "filters" to an endpoint, but accepts a generic callback where we execute our domain logic. Let's call these generic callbacks "actions" and create a testable seam in our application by moving these actions to a separate file.

~~~ text
  /cartridge
    /controllers
    /actions
~~~

~~~ javascript
  // controllers/Product.js
  var ShowAction = require("~/cartridge/actions/product/Show");
  module.exports.Show = guard.ensure([ "http", "get" ], ShowAction);

  // actions/product/Show.js
  module.exports = function ShowAction() {
    var template = "util/error",
      templateArgs = {};

    var ProductMgr = require("dw/catalog/ProductMgr"),
      product = ProductMgr.getProduct(request.httpParameterMap.pid.stringValue);

    if(product) {
      template = product.template || "product/product";
      templateArgs["Product"] = product;
    }

    var ISML = require("dw/template/ISML");
    ISML.renderTemplate(template, templateArgs);
  };
~~~

This separation allows our controller file to give a clear picture of the routes in our application. Also, if you have multiple controllers with similar logic, for example, an action that accepts a pid and returns a partial, we can create a reusable action that does this and apply it to a controller without duplicating code.

Although our actions are ready to test as standalone units, we need to manage the global dependencies DemandWare controllers rely on; specifically, the request object.

If you've written Angular applications, you're probably familiar with <a href="https://docs.angularjs.org/guide/di" alt="Dependency Injection">dependency injection</a>. We can pass the request dependency as an explicit parameter to our actions that we can then mock and test with accuracy. Since we're using the guard.ensure() function to filter our requests, we can modify guard.js to pass request as a parameter:

~~~ javascript
  // guard.js
  if (filtersPassed) {
      return action(request, params);
  } else { ... }
~~~

Now we can start writing true unit tests against our actions. We'll use the BDD testing framework <a href="https://github.com/jasmine/jasmine" alt="Jasmine">Jasmine</a> to write our expectations and build spies. We'll use <a href="https://github.com/boblauer/mock-require" alt="Mock-Require">mock-require</a> to mock our ProductMgr, ProductHelper, and ISML dependencies.

~~~ text
  npm install jasmine -g
  npm install mock-require --save-dev
~~~

~~~ javascript
  // product_actions_spec.js
  var mock = require("mock-require");
  var ShowAction = require([path_to_actions]"/actions/product/Show")

  describe("ShowAction", function () {
    it("renders an error template if no product exists", function () {
      var ProductMgr = jasmine.createSpyObj("ProductMgr", [ "getProduct" ]);
      ProductMgr.getProduct.and.returnValue(null);
      mock("dw/catalog/ProductMgr", ProductMgr);

      var ISML = jasmine.createSpyObj("ISML", [ "renderTemplate" ]);
      mock("dw/template/ISML", ISML);

      var request = { httpParameterMap: pid: { stringValue: "poprocks" }};

      ShowAction(request);

      expect(ProductMgr.getProduct).toHaveBeenCalledWith("poprocks");
      expect(ISML.renderTemplate).toHaveBeenCalledWith("util/error", {});
    });
  });
~~~

Let's dissect what's going on here.

~~~ javascript
  var ProductMgr = jasmine.createSpyObj("ProductMgr", [ "getProduct" ]);
  ProductMgr.getProduct.and.returnValue(null);
  mock("dw/catalog/ProductMgr", ProductMgr);

  var ISML = jasmine.createSpyObj("ISML", [ "renderTemplate" ]);
  mock("dw/template/ISML", ISML);
~~~

We mock the external libraries in our action. Since this is a unit test, we don't really care HOW the ProductMgr gets the product, nor do we really want it to make an actual database query to get a literal product. That's what integration and feature specs are for. We only care that our action calls ProductMgr.getProduct with a pid, and that our system responds properly when getProduct() returns null.

~~~ javascript
  var request = { httpParameterMap: pid: { stringValue: "poprocks" }};
~~~

Because we extended guard.js earlier to pass request as a parameter, we're able to mock the request object. In this case, we're passing a pid parameter with stringValue "poprocks", which we use later to see if ProductMgr.getProduct got the request param properly.

~~~ javascript
  ShowAction(request);

  expect(ProductMgr.getProduct).toHaveBeenCalledWith("poprocks");
  expect(ISML.renderTemplate).toHaveBeenCalledWith("util/error", {});
~~~

If you've ever written tests, this part is pretty vanilla. We call our Action (duh) and make assertions about what happened. Specifically, we called ProductMgr.getProduct() with the request param, and then rendered the "util/error" template. Now we can write a positive test:

~~~ javascript
  it("renders the pdp template", function () {
    var ProductMgr = jasmine.createSpyObj("ProductMgr", [ "getProduct" ]);
    ProductMgr.getProduct.and.returnValue({ name: "Fuzzy Socks" });
    mock("dw/catalog/ProductMgr", ProductMgr);

    var ISML = jasmine.createSpyObj("ISML", [ "renderTemplate" ]);
    mock("dw/template/ISML", ISML);

    var request = { httpParameterMap: pid: { stringValue: "fsocks" }};

    ShowAction(request);

    expect(ProductMgr.getProduct).toHaveBeenCalledWith("fsocks");
    expect(ISML.renderTemplate).toHaveBeenCalledWith("product/product", {
      "Product": { name: "Fuzzy Socks" }
    });
  });
~~~

Basically the same thing. This time, our ProductMgr passes back a pseudo-product named "Fuzzy Socks" and render "product/product" passing Product as a pipeline dictionary parameter.

I hope you've found this information useful. If you have any questions or concerns please feel free to follow me on Twitter.