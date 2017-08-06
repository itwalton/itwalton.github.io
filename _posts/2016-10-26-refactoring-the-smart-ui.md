---
layout: post
date: 2016-10-26
title: Refactoring the Smart UI
header: Refactoring the Smart UI
description: Identifying common pitfalls in Salesforce Commerce Cloud ISML templates and refactoring towards a deeper domain insight with Model decorators.
---

You're in a meeting with the domain expert discussing a new widget for the Product Details page. She wants to custom callout message for certain products when the product's inventory is below a specified threshold.

Weeks go by. The story has been pointed and prioritized. It's pulled into your sprint and you're ready to hit the ground running.

You drop an isif conditional in the product ISML template, drop the extra-special SEO-boosting callout message onto the page and call it finished.

But are you really?

We've all been in this situation countless times. Something about the awkward nature of pipelines or the functional nature of JavaScript makes us flock to template conditionals. While they certainly have their place in the Salesforce Commerce Cloud ecosystem, it's all too common to see bits of domain knowledge like this backed into your templates:

~~~ javascript
  <isif condition="${ pdict.Product.custom.canShowInventoryThreshold && pdict.Product.getAvailabilityModel().getInventoryRecord().getATS().getValue() <= dw.system.Site.getCurrent().getCustomPreferenceValue('inventoryThreshold')">
    ...
  </isif>
~~~

What's worse, this conditional gets repeated throughout multiple templates as time goes on. It becomes an untested pearl of domain-specific knowledge duplicated throughout the system.

What happens if someone fat-fingers inventoryThreshold? What happens if the product has no inventory record?

By the way, the answer is not to include null-checks in the conditional above.

Along with the SCC's Controllers release came bundled the ability to extend your favorite domain objects with custom methods. Utilizing the Decorator design pattern, ORM objects are "wrapped" with the Model class so objects retain their original methods while gaining access to methods specific to your domain. Let's see an example:

~~~ javascript
  var ProductModel = AbstractModel.extend({
    getEncodedName: function () { return this.object.getName().replace(/"/g, '\\"'); }
    ...
  });

  modules.export = ProductModel;
~~~

I'll skip over the gory details over AbstractModel, but suffice to say it's the syntactic sugar that extends the ORM object for customization. The object you pass to it defines the method accessible to your ProductModel instance.

To use our decorator, simply require it in your script and create a new instance:

~~~ javascript
  let ProductModel = require("path/to/ProductModel");
  let product = new ProductModel(pdict.Product);
~~~

We're passing the Product object from the pipeline dictionary in this example, but ideally you would initialize product from a Controller action, or simply from an Assign node in your Pipeline.

Going back to the original problem at hand, we can refactor the conditional towards a more concise domain by creating a new method on ProductModel:

~~~ javascript
  canShowInventoryCallout: function () {
    let site = require('dw/system/Site').getCurrent();
    let globalInventoryThreshold = site.getCustomPreferenceValue('inventoryThreshold');

    let productCanShowInventoryThreshold = this.getValue('canShowInventoryThreshold');
    let productInventoryOnHand = this.object.getAvailabilityModel().getInventoryThreshold().getATS().getValue();

    return productCanShowInventoryThreshold && productInventoryOnHand <= globalInventoryThreshold;
  }
~~~

~~~ javascript
  <isif condition="${ product.canShowInventoryCallout() }">
    ...
  <\isif>
~~~

Yes. This method is still messy. It knows way too much about the Site object, and pulling ATS inventory violates the Law of Demeter like nobody's business. But do you know what it <em>isn't</em>?

It isn't repeated in fragments throughout our code.

If we want to split fetching the site preference out into a separate method, it's one change versus many changes.

If the custom attribute 'canShowInventoryThreshold' has to be renamed, you can do so without wondering if a subtle defect will be exposed in your template logic downstream.

If you want to cache commonly used variables, you can do so without polluting your templates with isset or isscript tags.

And best of all, it's fully testable:

~~~ javascript
  // ProductModel.js
  getInventoryOnHand: function () {
    // do some stuff that returns inventory onhand
  },

  canShowInventoryCallout: function () {
    let site = require("path/to/SiteModel");
    let globalInventoryThreshold = site.getGlobalInventoryThreshold();

    let productCanShowInventoryThreshold = this.getValue('canShowInventoryThreshold');
    let inventoryOnHand = this.getInventoryOnHand();

    return productCanShowInventoryThreshold && inventoryOnHand < globalInventoryThreshold;
  },

  // test/product/model_spec.js
  it("is true for products with inventory below the global threshold", () => {
    let SiteMock = jasmine.createSpyObj("Site", ["getGlobalInventoryThreshold"]);
    SiteMock.getGlobalInventoryThreshold.and.returnValue(999999);
    mock("path/to/SiteModel", SiteMock);

    let product = new ProductModel({ custom: { canShowInventoryThreshold: true } });
    spyOn(product, "getInventoryOnHand").and.returnValue(1);

    expect(product.canShowInventoryCallout()).toBe(true);
  });

  it("is false for products with a disabled inventory callout");

  it("is false for products with inventory above the global threshold");
~~~

I hope you've found this information useful. If you have any questions or concerns please feel free to follow me on Twitter.