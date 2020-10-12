rxcui_ttys.fn <-  'build/rxcui_ttys.ttl'

# set the working directory to medication-knowledgegraph-pipeline/pipeline
# for example,
# setwd("~/GitHub/medication-knowledgegraph-pipeline/pipeline")

# get global settings, functions, etc. from https://raw.githubusercontent.com/PennTURBO/turbo-globals

# some people (https://www.r-bloggers.com/reading-an-r-file-from-github/)
# say it’s necessary to load the devtools package before sourcing from GitHub?
# but the raw page is just a http-accessible page of text, right?

# requires a properly formatted "turbo_R_setup.yaml" in medication-knowledgegraph-pipeline/config
# or better yet, a symbolic link to a centrally loated "turbo_R_setup.yaml", which could be used by multiple pipelines
# see https://github.com/PennTURBO/turbo-globals/blob/master/turbo_R_setup.template.yaml

source(
  "https://raw.githubusercontent.com/PennTURBO/turbo-globals/master/turbo_R_setup.R"
)

# Java memory is set in turbo_R_setup.R
print(getOption("java.parameters"))

####

# load public ontologies & RDF data sets
# inspired by disease_diagnosis_dev.R
# more refactoring (even package writing) opportunities

####    ####    ####    ####

### upload from file if upload from URL might fail
# the name of the destination graph is part of the "endpoint URL"

####    ####    ####    ####

# probably don't really need dron_chebi or dron_pro?

import.urls <- config$my.import.urls
import.names <- names(import.urls)
context.report <- get.context.report()
import.names <- setdiff(import.names, context.report)

placeholder <-
  lapply(import.names, function(some.graph.name) {
    some.ontology.url <- import.urls[[some.graph.name]]$url
    some.rdf.format <- import.urls[[some.graph.name]]$format
    import.from.url(some.graph.name,
                    some.ontology.url,
                    some.rdf.format)
  })

import.files <- config$my.import.files
import.names <- names(import.files)
context.report <- get.context.report()
import.names <- setdiff(import.names, context.report)

placeholder <-
  lapply(import.names, function(some.graph.name) {
    # some.graph.name <- import.names[[1]]
    some.ontology.file <- import.files[[some.graph.name]]$local.file
    some.rdf.format <- import.files[[some.graph.name]]$format
    import.from.local.file(some.graph.name,
                           some.ontology.file,
                           some.rdf.format)
  })

# "/Users/markampa/cleanroom/med_mapping/classified_search_results_from_robot.ttl.zip"
# "/Users/markampa/cleanroom/med_mapping/classified_search_results_from_robot.ttl"
# "/Users/markampa/cleanroom/med_mapping/reference_medications_from_robot.ttl

# import.from.local.file(
#   some.graph.name = "http://example.com/resource/classified_search_results",
#   some.local.file = "/Users/markampa/cleanroom/med_mapping/classified_search_results_from_robot.ttl",
#   some.rdf.format = "text/turtle"
# )

# need to wait for imports to finish
# file uploads may be synchronous blockers

last.post.status <-
  'Multiple OBO and BioPortal/UMLS uploads from URLs '
last.post.time <- Sys.time()

expectation <- import.names

monitor.named.graphs()

####    ####    ####    ####

sparql.list <-
  config$materializastion.projection.sparqls

placeholder <-
  lapply(names(sparql.list), function(current.sparql.name) {
    print(current.sparql.name)
    innner.sparql <- sparql.list[[current.sparql.name]]
    cat(innner.sparql)
    cat('\n\n')
    
    post.res <- POST(update.endpoint,
                     body = list(update = innner.sparql),
                     saved.authentication)
  })

####    ####    ####    ####

# RxNorm TTY types, asserted as employment

tryCatch({
  dbDisconnect(rxnCon)
},
warning = function(w) {
  
}, error = function(e) {
  print(e)
})

rxnCon <- NULL

connected.test.query <-
  "select RSAB from rxnorm_current.RXNSAB r"

# todo paramterize connection and query string
# how to user conenction parpatmeron LHS or assignment?
test.and.refresh <- function() {
  tryCatch({
    dbGetQuery(rxnCon, connected.test.query)
  }, warning = function(w) {
    
  }, error = function(e) {
    print(e)
    print("trying to reconnect")
    rxnCon <<- dbConnect(
      rxnDriver,
      paste0(
        "jdbc:mysql://",
        config$rxnav.mysql.address,
        ":",
        config$rxnav.mysql.port
      ),
      config$rxnav.mysql.user,
      config$rxnav.mysql.pw
    )
    dbGetQuery(rxnCon, connected.test.query)
  }, finally = {
    
  })
}

test.and.refresh()


my.query <- "
SELECT
RXCUI, TTY
from
rxnorm_current.RXNCONSO r
where
SAB = 'RXNORM'"

print(Sys.time())
timed.system <- system.time(rxcui_ttys <-
                              dbGetQuery(rxnCon, my.query))
print(Sys.time())
print(timed.system)

# # Close connection ?
# dbDisconnect(rxnCon)

rxcui_ttys$placeholder <- 1

rxcui.tab <- table(rxcui_ttys$RXCUI)
rxcui.tab <-
  cbind.data.frame(names(rxcui.tab), as.numeric(rxcui.tab))
names(rxcui.tab) <- c("RXCUI", "TTY.entries")

tty.tab <- table(rxcui_ttys$TTY)
tty.tab <-
  cbind.data.frame(names(tty.tab), as.numeric(tty.tab))
names(tty.tab) <- c("TTY", "RXCUI.entries")

# skip
# DF dose form like oral capsule
# DFG dose form group like oral product ?
# ET entry term
# PSN prfered  source name?
# SY synonym
# TMSY tallMAN synonym

one.per <-
  rxcui_ttys[rxcui_ttys$TTY %in% c(
    'BN',
    'BPCK',
    'GPCK',
    'IN',
    'MIN',
    'PIN',
    'SBD',
    'SBDC',
    'SBDF',
    'SBDG',
    'SCD',
    'SCDC',
    'SCDF',
    'SCDG'
  ), c('RXCUI', 'TTY')]

one.per.tab <- table(one.per$RXCUI)
one.per.tab <-
  cbind.data.frame(names(one.per.tab), as.numeric(one.per.tab))
names(one.per.tab) <- c("RXCUI", "TTY.entries")

print(table(one.per.tab$TTY.entries))

one.per$RXCUI <-
  paste0('http://purl.bioontology.org/ontology/RXNORM/',
         one.per$RXCUI)

one.per$TTY <-
  paste0('http://example.com/resource/rxn_tty/', one.per$TTY)

as.rdf <- as_rdf(x = one.per)

# todo parmaterize this hardcoding
rdf_serialize(rdf = as.rdf, doc = rxcui_ttys.fn, format = 'turtle')


post.res <- POST(
  update.endpoint,
  body = list(update = 'clear graph <http://example.com/resource/rxn_tty_temp>'),
  saved.authentication
)

placeholder <-
  import.from.local.file('http://example.com/resource/rxn_tty_temp',
                         rxcui_ttys.fn,
                         'text/turtle')

# move the statement to the config file
rxn.tty.update <- 'PREFIX mydata: <http://example.com/resource/>
insert {
graph mydata:employment {
?ruri mydata:employment ?turi .
}
}
where {
graph <http://example.com/resource/rxn_tty_temp> {
?s <df:RXCUI> ?r ;
<df:TTY> ?t .
bind(iri(?r) as ?ruri)
bind(iri(?t) as ?turi)
}
}'

# Added 203754 statements. Update took 16s, moments ago.

post.res <- POST(update.endpoint,
                 body = list(update = rxn.tty.update),
                 saved.authentication)

post.res <- POST(
  update.endpoint,
  body = list(update = 'clear graph <http://example.com/resource/rxn_tty_temp>'),
  saved.authentication
)

####    ####    ####    ####

if (FALSE) {
  # this should probably be optional... it is verbose,
  #   and the http://example.com/resource/elected_mapping replacement
  #   is proabbply more useful in most circumstances
  #   but it takes a long time to reload
  post.res <- POST(
    update.endpoint,
    body = list(update = 'clear graph <http://example.com/resource/classified_search_results>'),
    saved.authentication
  )
}
