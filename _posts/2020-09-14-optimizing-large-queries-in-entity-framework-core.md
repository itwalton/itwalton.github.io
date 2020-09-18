---
layout: post
date: 2020-09-14
title: Optimizing Large Queries in EFCore 3
header: Optimizing Large Queries in EFCore 3
description: Understanding how to mitigate request timeouts on queries returning large datasets
---

## Introduction

I recently joined a SaaS startup helping utility companies manage infrastructure and new-project collaboration, as an backend engineer. The application stack basically consists of few .NET Core microservices with a SQLServer DB in AWS RDS. My first task after joining was debugging & resolving an issue where customers experienced extreme latency on a particular page of our SPA web app.

## Error Logging and Profiling

Someone a lot smarter than me once said "listen to anecdotes, act on data", so instead of immediately hacking at the problem I installed some basic error logging and monitoring tools within AWS to try and tease out any more information. It become obvious immediately that a particular EFCore query written in LINQ was hanging and eventually timing out.

The next step was analyzing the RDS monitoring tools for any abnormalities. In this case, executing the query corresponded with a substantial jump in RAM utilization. I'm definitely not a DBA, but I took this to indicate a substantial number of records being retrieved and/or manipulated all at once. This gelled with my understanding of the purpose for the REST call in question and the volume of JOINs in the LINQ query.

Let me pause here and acknowledge the easy solution here - if your team has a budget capable of increasing RDS instance sizes or spinning up additional read replicas, that will *almost always* be cheaper for the business that investing engineering time to debug the issue. In this case, provisioning more resources was not in the cards and so down the rabbit hole I went.

The final (and important) step before writing code was profiling the query in question. While you may not learn anything new, I've found it can act as a helpful baseline when evaluating the success of your changes. And who knows? maybe there's an N+1 problem in some middleware that you weren't expecting. In this case, a quick scan with the Profiling utility in Azure Data Studio showed thousands of reads and mean query execution times exceeding 30s.

## Solution

Finally! Time to write some code. The offending EFCore/LINQ query read something like this:

~~~ csharp
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] FeatureListFilters filters) {
        List<Feature> features = await _dbContext
            .Where(f => f.Status.Equals(FeatureStatus.AVAILABLE))
            .Include(f => f.Layer)
                .ThenInclude(l => l.LayerProperties)
            .Include(f => f.Tasks)
                .ThenInclude(t => t.TaskTemplate)
                    .ThenInclude(t => t.TaskTemplateProperties)
            .ToListAsync();

        if (filters.meterNumbers.Count() > 0) {
            features = features.Select(f => filters.meterNumbers.Includes(f.meterNumber)).ToList();
        }

        return Ok(features.Select(f => _autoMapper.Map<ListFeatureResponse>(f)).ToList());
    }
~~~

If you're not familiar with EFCore/LINQ, the Include statement is effectively a JOIN on another table, where all objects are fetched in their entirety and models are instantiated in RAM. Then, an optional query param further the feature set _after_ it's read from the database, sent over the wire, loaded into RAM. Finally, in the Controller action's response the fully-qualified entities are trimmed down into DTOs and ASPNet magic serializes into JSON and sends a response.

Since we're not using the entities in outside of simply listing the DTOs, we can pass EFCore the DTO data contract and ask it to return on the information necessary to populate those objects:

~~~ csharp
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] FeatureListFilters filters) {
        List<ListFeatureResponse> listFeatureResponses = await _dbContext
            .Where(f => f.Status.Equals(FeatureStatus.AVAILABLE))
            .ProjectTo<ListFeatureResponse>()
            .ToListAsync();

        if (filters.meterNumbers.Count() > 0) {
            listFeatureResponses = listFeatureResponses.Select(f => filters.meterNumbers.Includes(f.meterNumber)).ToList();
        }

        return Ok(listFeatureResponses);
    }
~~~

This will eliminate any information on and JOINed entities like TaskTemplate or TaskTemplatePropertie that *aren't necessary* for the response from being read on the database, transmitted over the wire, and read into the application container's RAM. At scale this could mean substantial time savings.

*NOTE*: If you don't like AutoMapper (who could blame you?), you can still reach the same destination by constructing a DTO w/ a Select statement so long as it occurs before the query is executed w/ ToList.

But what if the `ListFeatureResponse` doesn't include meterNumber? We've just broken the subsequent filter. This issue may seem a bit pedantic, but it does demonstrate code rot as inexperienced developers find workaround for knowledge gaps. Let's fix it by chaining a separate Where clause:

~~~ csharp
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] FeatureListFilters filters) {
        IQueryable<Feature> featureQuery = _dbContext
            .Where(f => f.Status.Equals(FeatureStatus.AVAILABLE));

        if (filters.meterNumbers.Count() > 0) {
            featureQuery = featureQuery.Where(f => filters.meterNumbers.Includes(f.meterNumber));
        }

        List<ListFeatureResponse> listFeatureResponses = await featureQuery.ProjectTo<ListFeatureResponse>().ToListAsync();
        return Ok(listFeatureResponses);
    }
~~~

These two simple refactors eliminated the request timeouts and resulted in some happy customers. These changes were straightforward and intuitive - but were only possible because of setup steps of error logging, monitoring, profiling to diagnose the problem and quantitatively guage success. Seek first to understand, then be understood.

You may be wondering why I didn't add an index to the Feature collection? Maybe I could have - I'd certainly be interested in hearing constructive criticism from more knowledgeable members of the industry. In this case the code solution adequately resolved the issue and I saw no need to delve further. If the DB had been experiencing high CPU-utilization rather than RAM that may be an indication of inefficient reads or I/O problems, in which case reducing the number of records read w/ an index or something would be useful.

As always, thanks for reading. - Ian