// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

#show ref: it => locate(loc => {
  let target = query(it.target, loc).first()
  if it.at("supplement", default: none) == none {
    it
    return
  }

  let sup = it.supplement.text.matches(regex("^45127368-afa1-446a-820f-fc64c546b2c5%(.*)")).at(0, default: none)
  if sup != none {
    let parent_id = sup.captures.first()
    let parent_figure = query(label(parent_id), loc).first()
    let parent_location = parent_figure.location()

    let counters = numbering(
      parent_figure.at("numbering"), 
      ..parent_figure.at("counter").at(parent_location))
      
    let subcounter = numbering(
      target.at("numbering"),
      ..target.at("counter").at(target.location()))
    
    // NOTE there's a nonbreaking space in the block below
    link(target.location(), [#parent_figure.at("supplement") #counters#subcounter])
  } else {
    it
  }
})

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      block(
        inset: 1pt, 
        width: 100%, 
        block(fill: white, width: 100%, inset: 8pt, body)))
}



#let article(
  title: none,
  authors: none,
  date: none,
  abstract: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: "1",
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[Abstract] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}
#show: doc => article(
  title: [Evidence for ecological niche partitioning among ribbon and spotted seals in the Bering Sea and implications for their resilience to climate change],
  authors: (
    ( name: [Josh M. London],
      affiliation: [Alaska Fisheries Science Center],
      email: [josh.london\@noaa.gov] ),
    ( name: [Heather L. Ziel],
      affiliation: [Alaska Fisheries Science Center],
      email: [heather.ziel\@noaa.gov] ),
    ( name: [Lorrie D. Rea],
      affiliation: [University of Alaska, Fairbanks],
      email: [ldrea\@alaska.edu] ),
    ( name: [Stacie M. Koslovsky],
      affiliation: [Alaska Fisheries Science Center],
      email: [stacie.koslovsky\@noaa.gov] ),
    ( name: [Michael F. Cameron],
      affiliation: [Alaska Fisheries Science Center],
      email: [michael.cameron\@noaa.gov] ),
    ( name: [Peter L. Boveng],
      affiliation: [Alaska Fisheries Science Center],
      email: [peter.boveng\@noaa.gov] ),
    ),
  date: [2024-03-27],
  abstract: [In deep-diving seals \(#emph[Phocidae];) niche partitioning has been observed as delineation in time, multi-dimensional use of the ocean, or diet composition. Here, we focus on two species of seals in the Bering Sea – ribbon seals \(#emph[Histriophoca fasciata];) and spotted seals \(#emph[Phoca largha];) – and evidence for niche partitioning from two decades of bio-logger deployments \(n\=110 ribbon; n\=82 spotted) and stable isotope sampling \(n\=29 ribbon; n\=43 spotted). Whiskers of dependent pups in the spring reflect the isotopic space of adult female diet in the winter \(when the pup was developing in-utero) and sampling from the whisker base of adults in the spring corresponds with the isotopic space of their recent diet. In both seasons, spotted seals had higher mean δ13C \(winter: +6.9%; spring: +3.8%) and δ15N \(winter: +10.5%; spring \= +12.1%) values, which are reflective of on-shelf and coastal foraging at a higher trophic level. Two-dimensional utilization distributions \(UD) were estimated from bio-logger geolocations for each species during similar seasonal periods \('spring' and 'fall-winter'). Optimally weighted auto-correlated kernel density estimates were combined into a population UD to test spatial overlap. Greater overlap was observed in the spring when both species rely on the marginal sea-ice zone for pupping, breeding, and molting. More separation was observed during the fall-winter season when spotted seals remained largely on the continental shelf and ribbon seals shifted to the shelf break and Bering Sea basin. Dive behavior records showed ribbon seals consistently diving to deeper depths \(max dive depth \= \~600m) compared to spotted seals \(max dive depth \= \~300m) indicating additional partitioning of resources within the water column. Changes in the extent and timing of sea ice in the Bering Sea along with anomalous warming events could disrupt the niche partitioning between these seal species and, thus, challenge their resilience to climate change.

#block[
#callout(
body: 
[
Please note this analysis and manuscript is still in draft form and under active development. Changes to results, code, and the manuscript are likely and this should not be cited or used for any reason. We are sharing the work and development of this manuscript in the spirit of open science, improved transparency, and scientific reproducibility.

We plan to provide a preprint to bioRxiv prior to journal submission.

]
, 
title: 
[
Under Development. Please do not cite or use
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
)
]],
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)
#import "@preview/fontawesome:0.1.0": *


= Introduction
<introduction>
- review definition of niche partitioning;
- review of previous studies \(terrestrial/marine) of niche partitioning that relied on evidence from stable isotopes, geo-locations from bio-loggers, OR, for marine animals, dive behavior;
- highlight any studies that used an integrated approach \(e.g.~stable isotopes and movement). any previous studies that integrated across all three?
- review climate change impacts in the Arctic/Bering Sea and focus in on ribbon and spotted seals
- previously published studies, observations, LTK\(?), describing the ecology of ribbon and spotted seals that indicated potential for niche separation
- study objectives:
  - Do stable isotope and bio-logging data from nearly 2 decades of research provide evidence for niche partitioning among ribbon and spotted seals?
  - How might predicted climate change impacts in the Bering Sea affect this established partitioning of resources and will ribbon and spotted seals be resient to such change?

= Methods
<methods>
== Stable Isotope Analysis
<stable-isotope-analysis>
Whiskers, hair, and blood \(RBC and Plasma) from ribbon and spotted seals of all age classes were collected in the field as part of larger research efforts studying the ecology and health of ice-associated seals in the Bering Sea. All samples were collected from live seals captured in the spring \(April-June) within the marginal ice zone at the southern edge of sea-ice extent.

Stable isotope analysis was based on whiskers sampled from all age classes \(dependent pup, young of the year, subadult, adult) between 2009 and 2022. For all age classes, samples were taken along the length of the whisker starting at the root. Samples further from the root represent the isotopic space further back in time. Stable isotopes from whiskers of dependent pups in the spring reflect the isotopic space of adult female diets in the winter \(when the pup was developing in-utero) and sampling from the whisker base \(segment 2) of adults in the spring corresponds with recent isotopic use \(when those tissues were generated). Growth rates of whiskers in phocids are not linear and, thus, we can’t attribute a specific segment of the whisker to a specific point in time – except for the base segment near the root. Dependent pups, however, offer a unique opportunity because we know the majority of the whisker was developed in-utero and would represent the adult female’s forgaing during the preceding fall/winter. Once the pup starts nursing, however, the trophic level changes and we can expect segments nearest the root to reflect this. For this analysis we only consider samples from the distant half of the whisker to most closely match the in-utero period. We simply averaged those samples.

For comparison of the isotopic space, we used the R package, SIBER.

== Utilization Distributions from Bio-logger Deployments
<utilization-distributions-from-bio-logger-deployments>
A total of 112 bio-loggers \(SPLASH family, Wildlife Computers, Redmond, Washington, USA) were deployed on 67 ribbon seals and 45 spotted seals between 2005 and 2022. The deployments span all age classes with the exception of dependent pups for both species and were deployed during the months of April, May, and June. In some cases, deployments were initiated prior to molting and the bio-loggers fell off after a period of weeks to two months. Deployments initiated after molting transmitted up to \~9 months.

All deployments were checked for any data quality issues and inconsistent location estimates before they were run through a course speed filter to remove any locations that would have required a sustained swim speed greater than 15 km/h. Additionally, any deployments with fewer than 30 location estimates or a total deployment length less than 7 days were removed. Lastly, to improve movement model fitting, we thinned the location estimates to remove any time steps less than 10 minutes.

Two data sets for each species were created to include only movement in the months of April, May, and June \('spring') and October, November, and December \('open water'). The continuous time movement model used in the analysis is stationary and predicated on a general range limitation to the underlying movement behavior. Both species have known association with the marginal sea-ice zone during the spring months as they focus on pupping, breeding, and molting. The fall/winter months were chosen to match the time duration of the spring period when the Bering Sea is largely ice free. This period also coincides with the season when in-utero development of pups that are sampled for stable isotope analysis in the spring.

Utilization distributions were estimated for each species and each of the seasonal periods based on a continuous time movement model \(R package `ctmm`). Specifically, optimally weighted auto-correlated kernel density estimates \(wAKDE) were created to reflect a more honest account of space use while also mitigating sampling bias from irregular deployment lengths. The weighted AKDE utilization distributions were combined into a population kernel density estimate that should better reflect spatial distribution of the broader population beyond just the sampled seals.

== Dive Behavior From Bio-logger Deployments
<dive-behavior-from-bio-logger-deployments>
= Results
<results>
== Stable Isotope
<stable-isotope>
\(n \= 7 ribbon; n \= 31 spotted)

\(n \= 23 ribbon; n \= 35 spotted)

The figures below show results from the initial stable isotope analysis for pups sampled to represent adult female fall/winter foraging \(figure 1) and for sub-adults and adults \(figure 2) sampled to represent their foraging close to the time of sampling \(spring).

The plots show the values as well as a convex hull and an ellipse which represents the 95% confidence interval around the bivariate mean.

#block[
#block[
#figure([
#box(width: 297.0pt, image("index_files/figure-typst/unnamed-chunk-15-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Isotopic space of ribbon and spotted seal adult females in winter \(sampled from dependent pup whiskers that developed in-utero)
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


]
]
#block[
#block[
#figure([
#box(width: 297.0pt, image("index_files/figure-typst/unnamed-chunk-16-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Isotopic space of ribbon and spotted seal adults and sub-adults sampled from the root of the whisker sampled in the spring
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


]
]



