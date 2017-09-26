---
layout: post
date: 2017-09-25
title: Applied Quicksort in SFCC
header: Applied Quicksort in SFCC
description: An application of the quicksort algorithm to efficiently sort products in a product grid
---

Today I'd like to discuss a commonly occurring problem in Salesforce Commerce Cloud - namely how to efficiently sort products in memory.

Now, Salesforce/Demandware have done a great job providing an easy mechanism to sort products by a number of parameters (price, availability, custom attribute to name a few), but what happens when you need to apply a secondary filter to the elements in your grid?

I recently encountered a client whom wanted to keep the out-of-the-box sort values, but apply an implicit "secondary" sort by star rating. It wasn't a value in their sort dropdown; rather, after a customer applied a "price: low to high" sort on the product set, they wanted to prioritize products at the top of the grid by their star rating. Easy enough, right?

When I came across this requirement, it had already been implemented and pushed to production. Specifically, the products were iterated upon in the ISML template (SHAME) and pushed to one of five arrays, depending on the 1-5 possible star ratings. Then, five separate ISML loops rendered identical markup for the product tiles, ordered from highest to lowest. Something like this:

~~~ javascript
  let star1Array = new Array();
  let star2Array = new Array();
  let star3Array = new Array();
  let star4Array = new Array();
  let star5Array = new Array();

  while(pdict.Products.hasNext()) {
    let product = pdict.Products.next();
    if (product.custom.starRating == 1) {
      star1Array.push(product);
    } else if (product.custom.starRating == 2) {
      star2Array.push(product);
    }

    ....
  }
~~~

Now, at first glance, this gets the job done.. right?

What happens when the Marketing dept. comes back with hard analytics proving 4 star products have the highest conversion %? It'd require a code change.

What happens when your ratings integration of choice expands their ratings to support half-points? It'd require a code change.

As a software developer/hobbyist/craftsman, can we do better? I think so.

The <a href="https://en.wikipedia.org/wiki/Quicksort" title="Quicksort">Quicksort algorithm</a> is a must-have tool in any developers toolbox; it provides an easy, efficient method to sort an unsorted set of elements.

Now, you should probably know that I <a href="http://itwalton.com/blog/2016/10/26/refactoring-the-smart-ui" title="Refactoring the Smart UI">am not a fan of domain logic in templates</a>. So although not in scope for this post, I'd definitely recommend moving that logic to a model object (or at least the controller action).

The Quicksort algorithm takes a collection of n elements and recursively sorts them by a random "pivot" element for a best case run-time of O(nlogn) [worst case is O(n^2), but that's mitigated by the randomness of the pivot element for reasons not discussed here.]

In our star rating example, this would read something like:

~~~ javascript
  function swap(arr, i, j) {
    let temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
  }

  function partition(arr, start, end) {
    let random_pivot = parseInt(Math.random() * end + start);
    swap(arr, start, random_pivot);

    let i = start;
    for (var j = start + 1; j <= end; j++) {
      if (arr[j].custom.starRating >= arr[start].custom.starRating) {
        i++;
        swap(arr, i, j);
      }
    }

    swap(arr, i, start);
    return i;
  }

  function quicksort(arr, start, end) {
    if (start >= end) {
      return arr;
    }

    var pivot = partition(arr, start, end);
    quicksort(arr, start, pivot-1);
    quicksort(arr, pivot+1, end);
  }

  quicksort(pdict.Products, 0, pdict.Products.length - 1);
~~~

At a high-level, we want to
1. take a random element
2. partition the array around the element so that elements <= the pivot element are on the left (bounded by start to i), and elements > the pivot are on the right (bounded by pivot + 1 to end).
3. Repeat until all products have been sorted

Now we've got a sorted list of products (in memory) that we can iterate upon. We no longer need five loops in our template, it's not coupled to the increment of our starRating, and changing the ordering or prioritization of elements is in a single line (see partition method).

If you're sort of into understanding the mathematics behind this neat algorithm (and algorithms like it), I'd highly recommend <a href="https://www.coursera.org/learn/algorithms-divide-conquer" title="Divide and Conquer">Coursera's Divide and Conquer Algorithms course</a> taught by <a href="https://www.coursera.org/instructor/~768" title="Tim Roughgarden">Tim Roughgarden</a>.

Hope you enjoyed this post. For questions/concerns, please feel free to <a href="https://twitter.com/itwalton">follow me on Twitter</a>.