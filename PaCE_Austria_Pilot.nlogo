;; -------------------------------------------------------------------------------------------------------------------------------------------------------------
;; AUSTRIA PILOT MODEL OF THE PACE PROJECT, GRANT AGREEMENT ID: 822337, EU H2020
;;
;; This is Deliverable 2.2 of Work Package 2.
;;
;; Author: Ruth Meyer, Manchester Metropolitan University
;; in collaboration with our project partners at Salzburg University (Marco Fölsch, Martin Dolezal, Reinhard Heinisch)
;; -------------------------------------------------------------------------------------------------------------------------------------------------------------

;; Party strategies are taken from J. Muis & M. Scholte (2013): How to find the 'winning formula'? Acta Politica 48:22-46
;; they differentiate 4 types:
;; -- Sticker: party does not change position
;; -- Satisficer: party stops moving once aspired vote share is reached or surpassed and only starts moving again if loss > 25%
;; -- Aggregator: party moves towards average position of supporters
;; -- Hunter: party keeps moving in same direction if they gained vote share with last move, otherwise they turn around

;; Voter strategies are taken from R. Lau et al. (2018): Measuring voter decision strategies in political behavior and public opinion research
;;                                 Public Opinion Quarterly, 82:911-936
;; they differentiate 5 types:
;; -- Rational Choice: gather as much information as possible, compare all parties on all issues
;; -- Confirmatory: 'based on early affective-based socialization toward or against ... political parties, and a subsequent motivation
;;    to maintain cognitive consistency with the early learned affect. Party identification is generally the "lens" through which political
;;    information is selectively perceived. Information search is more passive than active" --> voting for party they feel closest to (partisanship)
;; -- Fast and frugal: try to be efficient, compare parties only on 1 or 2 (most important) issues
;; -- Heuristic-based: satisficing ("if one option meets my needs I will save time and go with it without really looking at others",
;;    choosing familiar candidate, follow recommendations of people/groups I trust, elimininating alternatives as soon as any negative information about them
;;    is encountered)
;; -- Go with gut: rely on intuition, make decisions based on what FEELS right

;; Other data is taken from surveys: AUTNES 2013 for voters, CHES 2014 for parties
;; have to align and select issues that both parties and voters find important and have a position on
;; -- found seven issues that work:
;;    party mips: "state intervention" "redistribution" "public services vs taxes" "immigration" "environment" "social lifestyle" "civil liberties vs. law and order"
;;    party vars: "econ_interven" "redistribution" "spendvtax" "immigrate_policy" "environment" "sociallifestyle" "civlib_laworder"
;;    voter mips: "economy" "welfare state" "budget" "immigration" "environmental protection" "society" "security"
;;    voter vars: "w1_q26_1" "w1_q26_2" "w1_q26_3" (add and reverse w1_q26_11/12 -> "a_immigration_index") "w1_q26_9" "w1_q26_6" "w1_q26_7"
;;    model issues: "economy" "welfare state" "spend vs taxes" "immigration" "environment" "society" "law and order" "left-right"

;; also separate visualisation from voters/parties position on issues (and add noise only for vis)
;; -- this includes being able to pick which issues should be displayed on x- and y-axis
;; -- if people DON'T have a position on an issue, they need to be assigned 3 = neither agree or disagree (if assigned 0 they look as if they are extreme left)

extensions [csv table factbase]

globals [
  voter-data party-data  ;; files with survey data
  party-names party-colours  ;; names and colours of parties
  ches-party-id-map     ;; mapping party ids used in CHES to party ids used in the model
  autnes-party-id-map   ;; mapping party ids used in AUTNES to party ids in model
  voter-mip-map         ;; map of voter mips used in the AUTNES survey to mips represented in the model
  voter-mip-probs       ;; distribution of mips derived from AUTNES
  party-mip-map         ;; map of party mips used in CHES to mips represented in the model
  party-mips            ;; list of most important issues for parties (taken from CHES)
  voter-mips            ;; matching list of most important issues for voters (taken from AUTNES) so that party-mips[i] = voter-mips[i]
  model-issues          ;; names for those issues used in the model
  current-display-issues  ;; which two issues are currently used to display the political landscape?
  strategy-probs        ;; probabilities for the strategies as defined by the model parameters
  ;; internal statistics
  pos-changes           ;; total number of position changes of voters
  inf-count             ;; total number of friend influences
]

breed [voters voter]
breed [parties party]

voters-own [
  id
  age
  gender
  education-level
  income-situation
  residential-area
  political-interest
  closest-party
  degree-of-closeness
  pp           ;; party propensities (propensity to vote for SPÖ, ÖVP, FPÖ, BZÖ, Grüne, Team Stronach)
  prob-vote    ;; probability to go vote (between 0 I will definitely not vote and 10 I will definitely vote)
  mvf-party    ;; anticipated vote choice ("might vote for ")
  voted-party  ;; party actually voted for (second wave of survey, only part of participants did this)
  my-positions  ;; stance on the modelled seven (eight) issues: 0: economy, 1: welfare state, 2: spend vs. taxes, 3: immigration, 4: environment, 5: society, 6: law and order, 7: left-right placement
  my-strategy  ;; type of voting decision-making strategy: 0 rational choice, 1: confirmatory, 2: fast and frugal, 3: heuristic-based, 4: go with gut
  my-issues    ;; list of issues important to this voter
  my-saliences  ;; list of weights for the issues (how important they are)
  my-opinions  ;; this now uses a factbase with columns issue, party, measure
               ;; this allows us to see a time line of opinion change and maybe "forget" opinions?
               ;; map of issue <---> party (which party can deal best with the issue), this is used in decision-making and can be changed by media/friends influence
               ;; an opinion is a list [<issue> <party> <measure-of-fitness>]
               ;; measure-of-fitness is a value from [-2 -1 0 1 2] with meaning very bad/bad/neutral/good/very good
               ;; this allows to calculate an overall "fitness" value for each party (if so desired) over all issues (that are important to a voter)
               ;; --- voters can exchange opinions when talking to friends; depending on the importance voters place on an issue, they have more/less chance of
               ;;     convincing the other one of their opinion; the degree-of-closeness to their closest-party should also influence that?
  current-p    ;; party this voter currently would vote for (if they voted)
  positions    ;; translated issue positions into Netlogo "space" coordinates
  pos-history  ;; history of positions
]

parties-own [
  id
  name
  our-positions ;; stance on the modelled seven (eight) issues: 0: economy, 1: welfare state, 2: spend vs. taxes, 3: immigration, 4: environment, 5: society, 6: law and order, 7: left-right placement
  our-issues    ;; most important issues for the party (data: mip1, mip2, mip3 --> all of them have to be mapped to the modelled issues)
  our-saliences ;; list of weights for the issues
  our-strategy  ;; type of party position adaptation strategy: 0 sticker 1 satisficer 2 hunter 3 aggregator
  vote-share    ;; history of the party's share of the votes, initialised with election result 2013 read in from file
  vs-change     ;; change to last election result (initialised with change to previous results read in from file)
  vs-aspiration-level ;; aspired level of vote share for strategy 'satisficing' (initialised with election result 2013 (or, if vs-change negative, result + change)
  h-dims        ;; dimensions chosen to move on for strategy 'hunter' (initialised with party's most important issue)
  h-dist        ;; distance for a move (0 if no move)
  positions     ;; translated issue positions into Netlogo space
  pos-history   ;; history of positions
]

to setup
  clear-all

  ask patches [ set pcolor 5 ]

  set voter-data "autnes2013_comma_2.csv"
  set party-data "Austria_2014_CHES_dataset.csv"

  set party-mips ["state intervention" "redistribution" "public services vs taxes" "immigration" "environment" "social lifestyle" "civil liberties vs. law and order"]
  set voter-mips ["economy" "welfare state" "budget" "immigration" "environmental protection" "society" "security"]
  set model-issues ["economy" "welfare state" "spend vs taxes" "immigration" "environment" "society" "law and order" "left-right"] ;; added left-right placement because both parties and voters have a position on that

  set current-display-issues (list x-issue y-issue)
  set strategy-probs read-from-string strategy-proportions

  set party-names ["NULL" "SPO" "OVP" "FPO" "BZO" "Greens" "NEOS" "Team Stronach"]
  set party-colours [9 red blue cyan yellow green orange pink]
  ;; party ids/names from CHES are: 1301	SPO, 1302	OVP 1303 FPO 1304	GRUNE 1306 NEOS 1307 BZO 1310	TeamStronach
  ;; ches-party-id-map maps these to the parties represented in the model
  set ches-party-id-map [0 1301 1302 1303 1306 1304 1307 1310]
  ;; party names for AUTNES are ["NULL" "SPOE" "OEVP" "FPOE" "FP Kaernten" "BZOE" "The Greens" "KPOE" "NEOS/LIF/JULIS" "Team Stronach" "Pirates" "other party" "no party"]
  ;; autnes-party-id-map maps these to the parties represented in the model (FP Kärnten merged with FPÖ, KPÖ/Piraten/other/no party ignored = 0)
  set autnes-party-id-map [0 1 2 3 3 4 5 0 6 7 0 0 0]
  ;; use distribution of mips derived from AUTNES for voters with answer 77777 (multiple issues) to assign a mip
  set voter-mip-probs [0.4202 0.3089 0.0787 0.1072 0.0574 0.0128 0.0148]

  set pos-changes 0
  set inf-count 0

  init-voter-mip-map
  init-party-mip-map
  show (word "creating parties ...")
  init-parties
  show  (word "creating voters ...")
  init-voters
  show (word "creating social network ...")
  create-social-network
  ;; initialise party attributes for hunter strategy
  ask parties [
    init-h-dims
    init-h-directions
  ]
  show (word "ready to roll!")
  reset-ticks
end

to init-voter-mip-map
  ;; represented mips are 10000 (economy), 11000 (welfare state), 12000 (budget), 14000 (security), 19000 (society), 20000 (environment), 22000 (immigration)
  ;; in this order: ["economy" "welfare state" "spend vs taxes" "immigration" "environment" "society" "law and order" "left-right"]
  set voter-mip-map table:make
  table:put voter-mip-map 10000 0  ;; "economy"
  table:put voter-mip-map 11000 1  ;; "welfare state"
  table:put voter-mip-map 12000 2  ;; "budget"
  table:put voter-mip-map 13000 -1 ;; "education and culture" ## -1: not represented in model
  table:put voter-mip-map 14000 6  ;; "security"
  table:put voter-mip-map 15000 -1 ;; "army"
  table:put voter-mip-map 16000 -1 ;; "foreign policy"
  table:put voter-mip-map 17000 -1 ;; "europe"
  table:put voter-mip-map 18000 -1 ;; "infrastructure"
  table:put voter-mip-map 19000 5  ;; "society"
  table:put voter-mip-map 20000 4  ;; "environmental protection"
  table:put voter-mip-map 21000 -1 ;; "institutional reform"
  table:put voter-mip-map 22000 3  ;; "immigration"
  table:put voter-mip-map 23000 -1 ;; "government formation"
  table:put voter-mip-map 24000 -1 ;; "ideology"
  table:put voter-mip-map 25000 -1 ;; "politics"
  table:put voter-mip-map 77777 -2 ;; "multiple issues"   ## -2: at least two issues
  table:put voter-mip-map 99999 -3 ;; "not classifiable"  ## -3: interpreted as none
end

to init-party-mip-map
  set party-mip-map table:make
  table:put party-mip-map "state intervention"	0
  table:put party-mip-map "redistribution"	1
  table:put party-mip-map "public services vs taxes"	2
  table:put party-mip-map "immigration"	3
  table:put party-mip-map "environment"	4
  table:put party-mip-map "deregulation"	0 ;; -1          ;; for now, we shall replace deregulation with "economy" (even though it's represented as position on state intervention; this concerns parties ÖVP, BZÖ, NEOS, Team Stronach)
  table:put party-mip-map "corruption"	-1
  table:put party-mip-map "anti-elite rhetoric"	-1
  table:put party-mip-map "urban vs rural"	-1
  table:put party-mip-map "nationalism"	6 ;;-1              ;; for now, we shall replace nationalism with law and order (this concerns parties FPÖ and BZÖ)
  table:put party-mip-map "social lifestyle"	5
  table:put party-mip-map "tie: deregulation and nationalism"	6 ;;-2
  table:put party-mip-map "civil liberties vs. law and order"	6
end

to init-voters
  ;; read in voter data from file and create voter agents
  file-close-all
  file-open voter-data
  let row csv:from-row file-read-line ;; discard header
  while [not file-at-end?] [

    set row csv:from-row file-read-line

    create-voters 1 [
      set id first row
      set gender item 1 row
      set age item 2 row
      set education-level item 3 row
      if (education-level = "") [ set education-level 0 ] ;; account for missing values
      set education-level convert-to-ed-range education-level
      set residential-area item 4 row
      if (residential-area = "") [ set residential-area 0 ]
      set income-situation item 5 row
      if (income-situation = "") [ set income-situation 0 ]
      set political-interest item 7 row
      if (political-interest = "") [ set political-interest 0 ]

      ;; read in most important issues from columns 9 (mip), 10 (mip second wave), 11 (mip-2)
      let mips []
      foreach [9 10 11] [ i ->
        set mips lput (convert-voter-mip item i row) mips
      ]
      ;; read-in parties best able to handle those issues from columns 12 (pmip), 13 (second wave), 14 (pmip-2)
      let pmips []
      foreach [12 13 14] [ i ->
        set pmips lput (convert-voter-party-id item i row) pmips
      ]
      ;; handle problems:
      ;; -- a mip of -1 means the voter issue is not represented in the model --> either do not use or assign a different issue for which the chosen pmip would be right
      ;; -- a mip of -2 means the voter had multiple issues --> assign two mips from the allowed list, use respective pmip for both (if set)
      ;; -- a mip of -3 means the voter issue was not classifiable or is missing --> do not enter into my-issues
      set my-issues []
      set my-saliences n-values length model-issues [0]
      let opmips handle-voter-mips mips pmips

      ;; assign opinions from issues and parties
      assign-opinions opmips

      set closest-party convert-voter-party-id item 16 row
      set degree-of-closeness item 17 row
      if (degree-of-closeness = "") [ set degree-of-closeness 0 ]

      ;; read in propensities to vote for the different parties
      let temp [0]
      let v item 18 row  ;; propensity to vote SPÖ (1)
      if (v = "") [ set v 0 ]
      set temp lput v temp
      set v item 19 row ;; propensity to vote ÖVP (2)
      if (v = "") [ set v 0 ]
      set temp lput v temp
      set v item 20 row ;; propensity to vote FPÖ (3)
      if (v = "") [ set v 0 ]
      set temp lput v temp
      set v item 21 row ;; propensity to vote BZÖ (4)
      if (v = "") [ set v 0 ]
      set temp lput v temp
      set v item 22 row ;; propensity to vote Grüne (5)
      if (v = "") [ set v 0 ]
      set temp lput v temp
      set temp lput 0 temp  ;; NEOS (6) is missing, people were not asked about it
      set v item 23 row ;; propensity to vote Team Stronach (7)
      if (v = "") [ set v 0 ]
      set temp lput v temp
      set pp temp

      set voted-party convert-voter-party-id item 24 row
      set prob-vote item 25 row
      if prob-vote = "" [ set prob-vote -1 ]
      set mvf-party convert-voter-party-id ifelse-value (prob-vote > 4) [item 27 row][item 28 row]

      ;; read in positions on model issues "economy" "welfare state" "spend vs taxes" "immigration" "environment" "society" "law and order" "left-right"
      ;; these are variables "w1_q26_1" "w1_q26_2" "w1_q26_3" (add and reverse w1_q26_11/12 -> "a_immigration_index") "w1_q26_9" "w1_q26_6" "w1_q26_7" "w1_q12"
      ;; which are found in columns 33 34 35 149 41 38 39 15
      ;; -- note that economy and law and order need to be reversed to match the scale of the associated CHES variables
      set temp []
      set v item 33 row  ;; state intervention in economy
      if (v = "") [ set v 3 ]  ;; #### if question not answered assign answer 3 = "neither agree nor disagree" instead of 0
      set v reverse-scale v
      set temp lput v temp
      set v item 34 row  ;; balance income difference
      if (v = "") [ set v 3 ]
      set temp lput v temp
      set v item 35 row  ;; spend vs. tax (in this case: fight unemployment)
      if (v = "") [ set v 3 ]
      set temp lput v temp
      set v item 149 row  ;; immigration policy
      if (v = "") [ set v 3 ]
      set temp lput v temp
      set v item 41 row  ;; environmental protection
      if (v = "") [ set v 3 ]
      set temp lput v temp
      set v item 38 row  ;; same rights for same-sex unions
      if (v = "") [ set v 3 ]
      set temp lput v temp
      set v item 39 row  ;; punish criminals severely
      if (v = "") [ set v 3 ]
      set v reverse-scale v
      set temp lput v temp
      set v item 15 row  ;; left-right self placement
      if (v = "") [ set v 3 ]
      set temp lput v temp
      set my-positions temp

      set current-p closest-party
      if (current-p = 0) [ set current-p mvf-party ]

      ;; assign decision-making strategy according to the "distribution" set by the model parameters
      set my-strategy sample-empirical-dist strategy-probs (range 1 6)

      set pos-history []

      set shape "person"
      set size age * 0.025
      set color item current-p party-colours
      ;; translate all positions
      translate-positions my-positions true
      ;; adopt coordinates to display
      update-coords

      ;; be attracted by closest party depending on degree of closeness
      let acp find-party closest-party
      if (acp != nobody) [
        face acp
        fd 4 - degree-of-closeness
      ]
    ]
  ]
  file-close
end

to-report handle-voter-mips [mlist plist]
  ;; mlist has three entries: m1 first wave, m1 second wave, m2 first wave
  ;; with the following possible exceptions:
  ;; -1 issue not represented in the model --> we pick 1 issue from the modelled list (or use m1 second wave instead)
  ;; -2 multiple issues (original: 77777) --> we pick 2 issues from the modelled list (or use m1 second wave instead)
  ;; -3 answer missing or not classifiable --> we ignore it (or use m1 second wave instead)

  ;; -- so first we check if we need to use the second entry
  let milist (list last mlist) ;; we definitely use the last entry: m2
  let pilist (list last plist)
  ifelse (first mlist < 0 and first but-first mlist >= 0) [
    ;; replace m1 first wave with m1 second wave
    set milist fput first but-first mlist milist
    set pilist fput first but-first plist pilist
  ][
    ;; we take m1 first wave
    set milist fput first mlist milist
    set pilist fput first plist pilist
  ]
  ;; now handle the exceptions
  set my-issues []
  let pmlist []
  foreach [0 1] [ i ->
    let mi item i milist
    (ifelse
      mi = -3 [
        ;; ignore it
      ]
      mi = -2 [
        ;; pick two issues according to the distribution defined in voter-mip-probs
        repeat 2 [
          ;; pick one issue
          let m get-a-mip
          if (not member? m my-issues) [   ;; avoid duplicates
            set my-issues lput m my-issues
            set pmlist lput item i pilist pmlist
          ]
        ]
      ]
      mi = -1 [
        ;; pick one issue
        let m get-a-mip
        if (not member? m my-issues) [
          set my-issues lput m my-issues
          set pmlist lput item i pilist pmlist
        ]
      ]
      ;; else
      [
        ;; take values across (unless duplicates!)
        if (not member? mi my-issues) [
          set my-issues lput mi my-issues
          set pmlist lput item i pilist pmlist
        ]
      ]
    )
  ]
  ;; assign importances (if there are any issues)
  let weights []
  foreach n-values length my-issues [i -> i] [ i ->
    set weights lput generate-a-weight weights
  ]
  if (not empty? weights) [ set weights adjust-weights weights ]
  foreach n-values length weights [i -> i] [ i ->
    set my-saliences replace-item (item i my-issues) my-saliences (item i weights)
  ]
  report pmlist
end

to-report generate-a-weight
  report precision (min (list 0.8 max (list 0.2 random-normal 0.5 0.1))) 3
end

to-report adjust-weights [wlist]
  while [sum wlist > 1] [
    ;; pick a random entry and reduce it by something between 0.001 and 0.05
    let i random length wlist
    set wlist replace-item i wlist (item i wlist - (0.001 + precision (random-float 0.049) 3))
  ]
  while [sum wlist < 1] [
    ;; pick a random entry and augment it by something between 0.001 and 0.04
    let i random length wlist
    set wlist replace-item i wlist (item i wlist + (0.001 + precision (random-float 0.039) 3))
  ]
  ;; make sure everything adds up to 1
  ;; pick a random entry and add missing bits
  if (sum wlist > 1) [
    let i random length wlist
    set wlist replace-item i wlist (item i wlist - precision (1 - sum wlist) 3)
  ]
  report sort-by > wlist
end


to assign-opinions [plist]
  ;; an opinion is a list [îssue party measure-of-success], with measure-of-success between -1 0 1   (for now)
  ;; using 0 if no party
  ;; using 1 if a party
  set my-opinions factbase:create ["issue" "party" "measure" "tick"]
  foreach n-values length my-issues [j -> j] [ i ->
    factbase:assert my-opinions (list item i my-issues item i plist ifelse-value (item i plist = 0)[0][1] -1)
    ;;set my-opinions lput (list item i my-issues item i plist ifelse-value (item i plist = 0)[0][1]) my-opinions
  ]
end

to assign-importance [mindex ilist]
  ;; most important issue (mindex = 1) gets slightly higher importance
  let imp 0
  ifelse (mindex = 1) [
    set imp min (list 0.8 max (list 0.4 random-normal 0.5 0.1))
  ][
    set imp min (list 0.49 max (list 0.2 random-normal 0.35 0.1))
    ;; check it's not too high
    ifelse (imp + sum my-saliences >= 1) [
      set imp 1 - sum my-saliences
    ][
      ;; pick a random issue not yet taken and give it the "rest" of the weight??? #####
    ]
  ]
  ;; insert into my-saliences at the right place(s)
  ifelse (last ilist >= 0) [
    ;; there are two issues (77777 originally) --> divide imp / 2 and put in both places
    set my-saliences replace-item (first ilist) my-saliences (imp / 2)
    set my-saliences replace-item (last ilist) my-saliences (imp / 2)
  ][
    set my-saliences replace-item (first ilist) my-saliences imp
  ]
end

to-report convert-voter-mip [iid]
  ;; convert read-in most important issue to model-internal issue
  if (iid = "") [ report -3 ]
  report table:get voter-mip-map iid
end

to-report convert-voter-party-id [p]
  ;; convert read-in party id to model-internal party id
  ;; this will involve some loss of information as we only recognise 7 parties (from CHES), not the 12 options from AUTNES (which include "no party")
  if (p = "") [ set p 0 ]
  report item p autnes-party-id-map
end

to-report convert-to-ed-range [e-level]
  let education-bounds [0 5 9 14 15] ;; upper bounds for NULL, low, medium, high, other
;;  let education-levels ["NULL" "low" "medium" "high" "other"]
  let i 0
  while [e-level > item i education-bounds and i < length education-bounds] [
    set i i + 1
  ]
;;  report item i education-levels
  report i
end

to-report reverse-scale [v]
   let value 6 - v
  report ifelse-value (value = 6) [0][value]
end

to-report add-some-noise
  ;;report 0
  report random-normal 0 0.4
end

to-report find-party [p-id]
  report one-of parties with [id = p-id]
end

to init-parties
  ;; read in strategies
  let pstr read-from-string party-strategies ;; one entry per party
  set pstr fput 0 pstr ;; add 0 for "NULL" party
  ;; read party data from file
  ;; file has these columns: party_name,party_id,econ_interven,redistribution,spendvtax,immigrate_policy,environment,sociallifestyle,civlib_laworder,
  ;;                         lrecon,multiculturalism,nationalism,mip_one,mip_two,mip_three,vote_share_2013,change
  file-close-all
  file-open party-data
  let row csv:from-row file-read-line ;; discard header
  while [not file-at-end?] [
    set row csv:from-row file-read-line
    create-parties 1 [
      set id position (item 1 row) ches-party-id-map
      set name item id party-names
      ;; read in positions on issues
      let temp []
      foreach n-values 8 [i -> 2 + i] [ x ->
        set temp lput (item x row) temp
      ]
      set our-positions temp
      ;; read in most important issues (columns 12-14)
      set temp[]
      foreach [12 13 14] [ x ->
        set temp lput (convert-party-mip item x row) temp
      ]
      handle-party-mips temp
      ;; read in 2013 election results and change to previous election (columns 15-16)
      set vote-share (list item 15 row)
      set vs-change item 16 row
      set vs-aspiration-level ifelse-value (vs-change < 0) [first vote-share - vs-change][first vote-share]  ;; if change is negative, party wants losses back

      set our-strategy item id pstr
      ;; h-dims and h-directions can only be set after voters have been created
      set pos-history []

      set shape "wheel"
      set size 2
      set color item id party-colours
      ;; translate all positions
      translate-positions our-positions false
      ;; adopt coordinates to display
      update-coords
    ]
  ]
  file-close
end

to-report convert-party-mip [mstring]
  ;; convert read-in most important issue to model-internal issue
  if (mstring = "") [ report -3 ]
  report table:get party-mip-map mstring
end

to handle-party-mips [mlist]
  ;; -1 means the issue is not represented in the model --> for now we just ignore it and remove it from the list
  ;; -2 and -3 do not occur as we already solved the one tie  and there are no missing answers
  set our-issues []
  foreach mlist [ m ->
    if (m >= 0 and not member? m our-issues) [ set our-issues lput m our-issues ]  ;; make sure there are no duplicates
  ]
  ;; assign importances:
  ;; if there are 3 issues, we use the weights CHES assigns (10/16, 5/16, 1/16)
  ;; if there are 2 issues, we use slightly adjusted weights 0.65, 0.35
  ;; if there is just 1 issue, weight is 1
  let weights [[1] [0.65 0.35] [0.625 0.3125 0.0625]]
  let w-index length our-issues - 1
  set our-saliences n-values (length model-issues - 1) [0]
  foreach n-values length our-issues [i -> i] [ i ->
    set our-saliences replace-item (item i our-issues) our-saliences (item i (item w-index weights))
  ]
end

to init-h-directions
  ;; right-wing parties tend to move further right on issues
  ;; left-wing parties tend to move further left, centre parties pick randomly
  ;; right-wing: position on left-right is >= 3.7, left-wing: left-right position is <= 2.3, centre in the middle
  ;; only set directions for the parties chosen hunter dimensions, leave the other issues 0
  let h-directions n-values (length positions - 1) [0]
  (ifelse
    last positions >= 3.7 [
      foreach h-dims [ i ->
        set h-directions replace-item i h-directions 1
      ]
    ]
    last positions <= 2.3 [
      foreach h-dims [ i ->
        set h-directions replace-item i h-directions -1
      ]
    ]
    [
      foreach h-dims [ i ->
          set h-directions replace-item i h-directions (-1 + random 3) ;; -1, 0 or 1
      ]
    ]
  )
  ;; now use heading to assign direction
  let vector map [x -> item x h-directions] h-dims
  set h-dist 0.5
  (ifelse
    vector = [0 1] [
      ;; move up = 0° in Netlogo
      set heading 0
    ]
    vector = [1 0] [
      ;; move right = 90°
      set heading 90
    ]
    vector = [0 -1] [
      set heading 180
    ]
    vector = [-1 0] [
      set heading 270
    ]
    vector = [1 1] [
      set heading 45
    ]
    vector = [1 -1] [
      set heading 135
    ]
    vector = [-1 -1] [
      set heading 225
    ]
    vector = [-1 1] [
      set heading 315
    ]
    [
      ;; else: don't move
      set heading 0
      set h-dist 0
    ]
  )
end

to init-h-dims
  ;; choose our two most important issues, or if we don't have two, our most important issue and the most important issue of the voters
  set h-dims our-issues
  if (length our-issues > 2) [
    set h-dims but-last h-dims
  ]
  if (length our-issues < 2) [
    ;; use most prominent mip of our supporters
    let pid id
    let sup-mip map [x -> occurrences x [first my-issues] of voters with [not empty? my-issues and current-p = id] ] range 7
    let sup-dim most-prominent sup-mip first our-issues
    set h-dims lput sup-dim h-dims
  ]
end

to-report most-prominent [ilist not-this]
  let mp position (max ilist) ilist
  while [mp = not-this and sum ilist > 0] [
    set ilist replace-item mp ilist 0
    set mp position (max ilist) ilist
  ]
  report mp
end

to go
  ;; parties update their vote share
  ask parties [
    set vote-share lput proportion-of-party id vote-share
    set vs-change last vote-share - (last but-last vote-share)
  ]

  ;; voters talk to other voters and influence each other several times per tick
  repeat 4 + random 2 [
    ask voters [
      ;; influence friends
      influence-friend
    ]
  ]
  ;; voters decide who they'd vote for at the moment according to their voting strategy
  ask voters [
    make-party-decision
  ]

  ;; parties decide to adapt their position according to their strategy
  ask parties [
    apply-strategy
  ]

  tick
end

;; ------------- party strategies ----------------------------------------------------------------

to apply-strategy
  (ifelse
    our-strategy = 0 [
      ;; party is a sticker = does not change its positions
      ;; do nothing
    ]
    our-strategy = 1 [
      ;; party is a satisficer
      p-satisficer
    ]
    our-strategy = 2 [
      ;; party is an aggregator
      p-aggregator
    ]
    our-strategy = 3 [
      ;; party is a hunter
      p-hunter
    ]
  )
end

to p-satisficer
  ;; check if we need to move at all: is current vote-share over threshold of 25% away from our aspiration?
  if (last vote-share < vs-aspiration-level - 25) [
    ;; move towards average position of supporters, aka be an aggregator
    p-aggregator
  ]
end

to p-aggregator
  ;; move towards average position of supporters on every dimension
  ;; if there aren't any supporters, move to average position of everyone
  set pos-history lput positions pos-history
  let pid id
  let supporters voters with [current-p = pid]
  if not any? supporters [ set supporters voters ]
  let pidx range (length positions - 1)
  let averages map [x -> mean [item x positions] of supporters] pidx  ;; calculate average positions of supporters on all issues (except left-right)
  let diffs map [x -> item x averages - item x positions] pidx        ;; calculate difference to our positions
  let directions map [x -> ifelse-value item x diffs >= 0 [1][-1]] pidx  ;; direction is sign of difference (+1 or -1)
  set diffs map [x -> min (list abs x 0.5)] diffs  ;; calculate absolute distance to move with maximum shift of 0.5 per step
  let new-positions map [x -> item x positions + (item x directions) * (item x diffs)] pidx
  ;; add unchanged left-right position
  set new-positions lput (last positions) new-positions
  set positions new-positions
end

to p-hunter
  ;; continue shifting in current direction if previous move was successful; otherwise change direction
  ;; we shall only consider the two most important issues for the party
  set pos-history lput positions pos-history
  if (vs-change < 0) [
    ;; not successful --> change direction
    set heading heading - 180 ;; turn around
    set heading heading - 90 + random 180 ;; choose randomly in 180° arc we are now facing
  ]

  set hidden? true
  let my-xy (list xcor ycor) ;; remember my position on screen
  setxy (item (first h-dims) positions) (item (last h-dims) positions)
  fd h-dist
  ;; retrieve new positions
  set positions replace-item (first h-dims) positions xcor
  set positions replace-item (last h-dims) positions ycor
  ;; restore vis (if displayed issues are different from dimensions we just moved on)
  if (first h-dims != position x-issue model-issues) [
    set xcor first my-xy
  ]
  if (last h-dims != position y-issue model-issues) [
    set ycor last my-xy
  ]
  set hidden? false
end

;; ------------- voters influencing each other --------------------------------------------------

to influence-friend
  ;; meet a friend and talk about politics, depending on political interest level:
  ;; 1 very interested
  ;; 2 fairly
  ;; 3 a little
  ;; 4 not at all
  if (random 4 <= (4 - political-interest) and any? link-neighbors) [
    set inf-count inf-count + 1
    ;; pick a random friend to talk to
    let friend one-of link-neighbors
    ;; voters could be influenced on (a) their positions (b) their saliences (c) their opinions on which party is best for which issue
    ;; we'll ignore the saliences for now ###
    ;; if I have opinions try and change theirs to one of mine
    ifelse (factbase:size my-opinions > 0 and random-float 1 < 0.5) [
      ;; pick an issue I have an opinion about
      let i one-of opined-issues
      ;; what do I think is the best party for this?
      let olist opinions-of-issue i
      let bestp best-party-for-issue i
      ask friend [
        adopt-opinion i bestp item (position bestp reverse parties-of olist) reverse measures-of olist
      ]
    ][
      ;; pick one of my most important issues (or a random issue if I don't have any mips)
      ;; and try and make them change their position on that issue
      let i ifelse-value (empty? my-issues) [random length my-saliences] [one-of my-issues]
      if (item i my-saliences > item i [my-saliences] of friend) and (random 1 < voter-adapt-prob) [
        ask friend [
          adjust-position i myself
        ]
      ]
    ]
  ]
end

to adopt-opinion [io po mo]
  ;; there are other ways to go about this... ###
  let ilist opined-issues
  ;; if I don't have an opinion on the given issue
  if (not member? io ilist) [
    add-opinion io po mo
    stop
  ]
  ;; if I already have an opinion but I like the given party better
  if (closest-party = po or item po pp > 5) [
    add-opinion io po mo
  ]
end

to adjust-position [issue friend]
  set pos-history lput positions pos-history
  set pos-changes pos-changes + 1
  ;; move towards friend's position on issue
  let value item issue positions
  let f-value item issue [positions] of friend
  set positions replace-item issue positions ((f-value - value) / 10 + value)
end


;; ------------- Voting behaviour stuff ----------------------------------------------------------

to make-party-decision
  (ifelse
    my-strategy = 1 [
      set current-p rational-choice
    ]
    my-strategy = 2 [
      set current-p confirmatory
    ]
    my-strategy = 3 [
      set current-p fast-and-frugal
    ]
    my-strategy = 4 [
      set current-p heuristic-based
    ]
    my-strategy = 5 [
      set current-p go-with-gut
    ]
    [
      set current-p 0
    ]
  )
  ;; change my color to the colour of current-p
  set color item current-p party-colours
end


;; strategy 1: rational choice decision-making
to-report rational-choice
  ;; pick party closest on all issues (using plain distance)
  let plist sort parties
  let dlist []
  let pdlist []
  foreach plist [ p ->
    set dlist lput (weighted-distance-to p) dlist
    set pdlist lput (plain-distance-to p) pdlist
  ]
;  show (word "weighted distance " dlist " to parties " plist)
;  show (word "plain distance " pdlist " to parties " plist)
;  let best position (min dlist) dlist + 1 ;; position returns index in list starting with 0, party ids start with 1
  let best position (min pdlist) pdlist + 1
  report best
end

;; strategy 2: confirmatory decision-making
to-report confirmatory
  ;; go with closest party if it exists
  if (closest-party != 0) [
    report closest-party
  ]
  ;; if there is none, find the party with most positive measures in my opinions
  let plist opined-parties
  ;; if I have no opinions, report 0
  if (empty? plist) [
    report 0
  ]
  let mlist []
  foreach plist [ p ->
    set mlist lput sum measures-of-party p mlist
  ]
  let best position (max mlist) mlist
  report item best plist
end

;; strategy 3: fast and frugal decision-making
to-report fast-and-frugal
  ;; pick party closest on 1 or 2 most important issues (using weighted distance)
  let plist sort parties
  let dlist []
  let pdlist []
  let num-issues min (list 2 length my-issues)
  let dimensions sublist my-issues 0 num-issues
  foreach plist [ p ->
    set dlist lput (weighted-distance-in-dims-to p dimensions) dlist
    set pdlist lput (plain-distance-in-dims-to p dimensions) pdlist
  ]
;  show (word "weighted distance " dlist " to parties " plist)
;  show (word "plain distance " pdlist " to parties " plist)
  let best position (min dlist) dlist + 1
  report best
end

;; strategy 4: heuristic-based decision-making
to-report heuristic-based
  ;; problem here: it's not one strategy, examples given describe three different ones
  ;; (a) choosing a familiar candidate (pick party most heard about)
  ;; (b) satisficing: if one option meets my needs, don't look into others (pick first party that's "good enough")
  ;; (c) follow recommendations of friends (pick party most popular amongst my friends?)
  ;; -- we'll go with c for now since it's most different from the others
  ;; -- but only if this voter doesn't have a closest-party they actually feel close to (this could resemble (a))
;  if (closest-party > 0 and degree-of-closeness <= 2) [
;    report closest-party
;  ]
  ;; see if I have an opinion which is the best party for my most important issue
;  if (not empty? my-issues) [
;    let best best-party-for-issue first my-issues
;    if (best != 0) [
;      report best
;    ]
;  ]
  ;; check which party my friends will vote for
;  let plist [current-p] of link-neighbors
;  let olist map [x -> occurrences x plist] range length party-names
;  let best position (max olist) olist
;  report best
  report any-of-maj
end

to-report first-of-maj
  let plist [current-p] of link-neighbors
  let olist map [x -> occurrences x plist] range length party-names
  report position (max olist) olist
end

to-report any-of-maj
  let plist [current-p] of link-neighbors
  let olist map [x -> occurrences x plist] range length party-names
  let hp max olist
  let hpx position hp olist
  if (occurrences hp olist > 1) [
    let highestp all-positions-of hp olist
    set hpx one-of highestp
  ]
  report hpx
end

;; strategy 5: gut decision-making
to-report go-with-gut
  let p 0
  ;; we will use the propensities to vote for this
  ;; problem only if all propensities are 0 (sum pp = 0; this is true for 193 of the survey participants)
  if (sum pp = 0) [
    ;; pick closest party if it exists and degree-of-closeness <= 2, or random party -- if prob-vote > 4
    if (prob-vote > 4) [
      ifelse (closest-party != 0 and degree-of-closeness <= 2) [
        set p closest-party
      ][
        set p [id] of one-of parties
      ]
    ]
    report p
  ]
  ;; pick the party with highest propensity
  ;; -- if there is a tie, pick the party the voter feels closest to (if degree-of-closeness <= 2), otherwise choose randomly between them
  let hp max pp
  set p position hp pp ;; first entry in pp is for "NULL" party, so the other entries match the party id
  if (occurrences hp pp > 1) [
    let highestp all-positions-of hp pp
    ifelse (member? closest-party highestp and degree-of-closeness <= 2) [
      ;; closest party is one of the highest propensity ones --> take it!
      set p closest-party
    ][
      ;; pick a random one out of the highest propensity ones
      set p one-of highestp
    ]
  ]
  report p
end

;; ------------- utils for opinions -------------------------------------------------------------

to-report opined-parties
  let result factbase:retrieve-to my-opinions [true][]["party"]
  report flatten-u result ;;list-to-set flatten result
end

to-report opined-issues
  let result factbase:retrieve-to my-opinions [true][]["issue"]
  report flatten-u result
end

to-report measures-of-party [p]
  ;; find and report all measures related to the given party
  let result factbase:retrieve-to my-opinions [x -> x = p]["party"]["measure"]
  report flatten result
end

to-report opinions-of-party [p]
  ;; find all opinions related to the given party
  report factbase:retrieve my-opinions [x -> x = p]["party"]
end

to-report opinions-of-issue [i]
  ;; find all opinions related to the given issue
  report factbase:retrieve my-opinions [x -> x = i]["issue"]
end

to-report recent-opinions-of-party [p time-period]
  ;; find all opinions related to the given party within the last time-period
  report factbase:retrieve my-opinions [[x t] -> x = p and t >= ticks - time-period]["party" "tick"]
end

to-report best-party-for-issue [i]
  let iolist opinions-of-issue i  ;; these are all my opinions on the issue, with newest opinion last
  if (empty? iolist) [ report 0 ]
  let plist parties-of iolist
  let mlist measures-of iolist
  let best position (max mlist) reverse mlist
  report item best reverse plist
end

to-report issues-of [olist]
  report map [x -> issue-of x] olist
end

to-report parties-of [olist]
  report map [x -> party-of x] olist
end

to-report measures-of [olist]
  report map [x -> measure-of x] olist
end


to-report issue-of [o]
  report first o
end

to-report party-of [o]
  report first but-first o
end

to-report measure-of [o]
  report last but-last o
end

to-report time-of [o]
  report last o
end

to add-opinion [o-issue o-party o-measure]
  factbase:assert my-opinions (list o-issue o-party o-measure ticks)
end

to remove-opinion [o]
end

;; ------------- Social network stuff ------------------------------------------------------------

to create-social-network
  ask voters [
    make-links random 5
  ]
end

to make-links [n]
  repeat n [
    ;; pick some candidates
    let candidates sort n-of 10 other voters
    make-new-link candidates
  ]
end

to make-new-link [candidate-list]
  ;; form a link with the most similar one of the possible new friends
  create-link-with most-similar candidate-list [ set hidden? true ]
end

to-report most-similar [candidate-list]
  let scores map [x -> similarity-score x] candidate-list
  let index position (min scores) scores ;; the smaller the score, the more similar
  report item index candidate-list
end

to-report similarity-score [another]
  ;; see how similar the other is to myself in education, residential-area and age
  let age-dist abs (age - [age] of another) / 80
  let ed-dist abs (education-level - [education-level] of another) / 15
  let res-dist abs (residential-area - [residential-area] of another) / 5
  report age-dist + ed-dist + res-dist
end

to-report mean-similarity
  if (not any? my-links) [ report 0 ]
  report mean map [x -> similarity-score x] ([other-end] of my-links)
end

to-report max-similarity
  if (not any? my-links) [ report 0 ]
  report max map [x -> similarity-score x] ([other-end] of my-links)
end

to-report min-similarity
  if (not any? my-links) [ report 0 ]
  report min map [x -> similarity-score x] ([other-end] of my-links)
end

to toggle-link-visibility
  ifelse ([hidden?] of one-of links) [
    ask links [set hidden? false]
  ][
    ask links [set hidden? true]
  ]
end

;; --------------- visualisation  ----------------------------------------------------------------------------------------------------------

to redraw-world
  ;; change dimensions if necessary
  if (first current-display-issues != x-issue or last current-display-issues != y-issue) [
    change-dimensions
    set current-display-issues replace-item 0 current-display-issues x-issue
    set current-display-issues replace-item 1 current-display-issues y-issue
  ]
end

to update-coords
  ;; turtle procedure
  setxy item (position x-issue model-issues) positions item (position y-issue model-issues) positions
end

to translate-positions [plist with-noise?]
  set positions []
  foreach plist [ p ->
    set positions lput translate-to-vis (p + ifelse-value (with-noise?)[add-some-noise][0]) positions
  ]
end

to change-dimensions
  ;; ask both parties and voters to change their xcor and ycor to displayed issues
  ask turtles [
    update-coords
  ]
end

to-report translate-to-vis [coord]
  report coord * 11 - 33
end

to-report translate-from-vis [coord]
  report (coord + 33 ) / 11
end


;; --------------- utils -------------------------------------------------------------------------------------------------------------------

to-report all-positions-of [value alist]
  ;; find all positions of value in the given list
  let result []
  if (not member? value alist) [ report result ]
  let i position value alist
  let j 0
  while [i != false and j < length alist] [
    set result lput (i + j) result
    set j j + i + 1
    set i position value sublist alist j length alist
  ]
  report result
end

to-report flatten [lol]
  ;; lol is a list of lists with single elements
  let result []
  foreach lol [ l ->
    set result lput first l result
  ]
  report result
end

to-report list-to-set [the-list]
  ;; turn list into set = list with only unique elements
  let the-set []
  foreach the-list [ l ->
    if (not member? l the-set) [ set the-set lput l the-set ]
  ]
  report the-set
end

to-report flatten-u [lol]
  ;; lol is a list of lists with single elements
  ;; report unique elements (set of flattened list)
  ;; -- this is probably faster than list-to-set flatten lol because we only go through the list once
  let result []
  foreach lol [ l ->
    let fl first l
    if (not member? fl result) [ set result lput fl result ]
  ]
  report result
end

to-report plain-distance-to [another]
 ;; compute n-dimensional distance over all positions (except the left-right one)
  report plain-distance-in-dims-to another n-values (length positions - 1) [j -> j]
end

to-report weighted-distance-to [another]
  ;; compute weighted n-dimensional distance over all positions (except the left-right one)
  ;; this assumes that my-saliences has weights for ALL positions (some may be 0 of course)
  report weighted-distance-in-dims-to another n-values (length positions - 1) [j -> j]
end

to-report plain-distance-in-dims-to [another dims]
  ;; compute only selected dimensions (issues) given by dims as a list e.g. [0 3 4]
  let d []
  foreach dims [ i ->
    set d lput ((item i positions - item i [positions] of another) ^ 2) d
  ]
  report sqrt sum d
end

to-report weighted-distance-in-dims-to [another dims]
  ;; compute only selected dimensions (issues) given by dims as a list e.g. [0 3 4]
  let d []
  foreach dims [ i ->
    set d lput (item i my-saliences * (item i positions - item i [positions] of another) ^ 2) d
  ]
  report sqrt sum d
end

to-report proportion-of-party [p]
  let n count voters
  if (n = 0) [ report 0 ]
  report count voters with [current-p = p] / n * 100
end

to-report get-a-mip
  report sample-empirical-dist voter-mip-probs n-values (length voter-mip-probs) [i -> i]
end

;; count the number of occurrences of an item in a list
to-report occurrences [x the-list]
  report reduce
    [ [occurrence-count next-item] -> ifelse-value (next-item = x) [occurrence-count + 1] [occurrence-count] ] (fput 0 the-list)
end

to-report sample-empirical-dist [probabilities values]
  ;; probabilities are not accumulated but add up to 1.0
  ;; there is a probability for each value
  let k random-float 1.0
  let i 0
  let lower-bound 0
  while [i < length probabilities] [
    ifelse (k < precision (lower-bound + item i probabilities) 4) [
      report item i values
    ] [
      set lower-bound precision (lower-bound + item i probabilities) 4
      set i i + 1
    ]
  ]
  show (word "ERROR in sample-empirical-distribution with probs " probabilities " and values " values " // k = " k " and i = " i)
  report -1
end
@#$#@#$#@
GRAPHICS-WINDOW
157
15
704
563
-1
-1
7.0
1
10
1
1
1
0
1
1
1
-38
38
-38
38
1
1
1
ticks
30.0

BUTTON
35
16
120
49
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
33
139
120
172
toggle links
toggle-link-visibility
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
8
201
149
246
x-issue
x-issue
"economy" "welfare state" "spend vs taxes" "immigration" "environment" "society" "law and order" "left-right"
0

CHOOSER
8
249
149
294
y-issue
y-issue
"economy" "welfare state" "spend vs taxes" "immigration" "environment" "society" "law and order"
2

BUTTON
36
302
110
335
update
redraw-world
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
722
15
1122
57
Proportions of decision-making strategies:\nRational choice / Confirmatory / Fast and frugal / Heuristics-based / Go with gut
11
0.0
1

PLOT
720
237
1174
427
Voting Poll
time
party proportions
0.0
10.0
0.0
50.0
true
true
"" ""
PENS
"null" 1.0 0 -11053225 true "" "plot proportion-of-party 0"
"SPÖ" 1.0 0 -2674135 true "" "plot proportion-of-party 1"
"ÖVP" 1.0 0 -13345367 true "" "plot proportion-of-party 2"
"FPÖ" 1.0 0 -11221820 true "" "plot proportion-of-party 3"
"BZÖ" 1.0 0 -1184463 true "" "plot proportion-of-party 4"
"Greens" 1.0 0 -10899396 true "" "plot proportion-of-party 5"
"NEOS" 1.0 0 -955883 true "" "plot proportion-of-party 6"
"T.Stro" 1.0 0 -2064490 true "" "plot proportion-of-party 7"

BUTTON
34
57
120
90
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
33
98
119
131
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
4
355
149
388
voter-adapt-prob
voter-adapt-prob
0
1
0.1
0.05
1
NIL
HORIZONTAL

INPUTBOX
717
50
946
110
strategy-proportions
[0 0 1 0 0]
1
0
String

INPUTBOX
717
153
966
213
party-strategies
[0 0 0 0 0 0 0]
1
0
String

TEXTBOX
723
118
1081
160
Strategy for parties:\n0 : sticker, 1 : satisficer, 2 : aggregator, 3 : hunter (one entry per party)
11
0.0
1

@#$#@#$#@
## WHAT IT IS

This is the first version of a model exploring voting behaviour in Austria. The aim of the model is to identify the processes that lead to specific election outcomes. Austria was chosen as a case study because it has an established populist party (the "Freedom Party" FPÖ), which has even been part of the government over the years.

## HOW IT WORKS

The model distinguishes between voters and parties. Both are initialised from publicly available empirical data, the 2013 AUTNES voter survey comprising 3266 individuals and the 2014 Chapel Hill Expert Survey (CHES) comprising 7 parties for Austria. The necessary files are bundled with the model code.

From these surveys we identified seven common issues that are used as the dimensions of the political landscape: economy (pro/against state intervention in the economy), welfare state (pro/against redistribution of wealth), budget (pro/against raising taxes to increase public services), immigration (against/pro restrictive immigration policy), environment (pro/against protection of the environment), society (pro/against same rights for same-sex unions), law and order (against/pro strong measures to fight crime, even to the detriment of civil liberties).

Both voters and parties are located in this landscape by means of their positions on the respective issues. Since seven issues are difficult to visualise in two dimensions, the model only maps two of these issues at a time to the x- and y-axis of the world. The user can choose which ones to display via the model parameters _x-issue_ and _y-issue_ and then pressing the _update_ button.

The parties are represented as wheels and are assigned a colour: SPÖ red, ÖVP blue, FPÖ cyan, BZÖ yellow, The Greens (green), NEOS (orange), Team Stronach (pink). In addition to their positions on the seven issues, they all identify 2-3 of these as their most important issues and assign a weight to them.

The voters are represented as persons; their size grows with age. They adopt the colour of the party they would currently vote for (light grey, if none). Voters are characterised by demographic attributes (age, sex, education level, income level, area of residence), political attitudes (political interest, party they feel closest to and degree of that closeness, propensities to vote for either of the parties). They also have positions on all seven issues (my-positions), identify up to 3 of these issues as most important (my-issues) and assign weights to them according to their importance (my-importances). In addition, they have opinions on which party is best (or not) to handle a particular issue.

Via their social network (initialised as a mixture of random and homophilic 

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

To explore the different dimensions ("issues") of the political landscape you can pick which of them should be displayed by selecting one for each of the model p x-issue and y-issue, respectively.

## EXTENDING THE MODEL

This is a work in progress. Our next steps will be to include the influence of the media on voter behaviour and different strategies for parties to change their position(s) in the political landscape.


## CREDITS AND REFERENCES

This model is Deliverable 2.2 of the PaCE (Populisam and Civic Engagement) project, see http://popandce.eu/. Funded by the EU H2020 under Grant agreement ID: 822337.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="first-test" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="24"/>
    <metric>proportion-of-party 0</metric>
    <metric>proportion-of-party 1</metric>
    <metric>proportion-of-party 2</metric>
    <metric>proportion-of-party 3</metric>
    <metric>proportion-of-party 4</metric>
    <metric>proportion-of-party 5</metric>
    <metric>proportion-of-party 6</metric>
    <metric>proportion-of-party 7</metric>
    <enumeratedValueSet variable="voter-adapt-prob">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational-choice-strategy">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confirmatory-strategy">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fast-frugal-strategy">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="heuristics-strategy">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gut-strategy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="y-issue">
      <value value="&quot;society&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x-issue">
      <value value="&quot;environment&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="behaviour-experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="12"/>
    <metric>proportion-of-party 0</metric>
    <metric>proportion-of-party 1</metric>
    <metric>proportion-of-party 2</metric>
    <metric>proportion-of-party 3</metric>
    <metric>proportion-of-party 4</metric>
    <metric>proportion-of-party 5</metric>
    <metric>proportion-of-party 6</metric>
    <metric>proportion-of-party 7</metric>
    <enumeratedValueSet variable="strategy-proportions">
      <value value="&quot;[1 0 0 0 0]&quot;"/>
      <value value="&quot;[0 1 0 0 0]&quot;"/>
      <value value="&quot;[0 0 1 0 0]&quot;"/>
      <value value="&quot;[0 0 0 1 0]&quot;"/>
      <value value="&quot;[0 0 0 0 1]&quot;"/>
      <value value="&quot;[0.2 0.2 0.2 0.2 0.2]&quot;"/>
      <value value="&quot;[0.15 0.15 0.3 0.3 0.1]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="y-issue">
      <value value="&quot;immigration&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x-issue">
      <value value="&quot;law and order&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voter-adapt-prob">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
