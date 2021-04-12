globals
[
  grid-x-inc               ;; the amount of patches in between two roads in the x direction
  grid-y-inc               ;; the amount of patches in between two roads in the y direction
  acceleration             ;; the constant that controls how much a car speeds up or slows down by if
                           ;; it is to accelerate or decelerate
  phase                    ;; keeps track of the phase
  num-cars-stopped         ;; the number of cars that are stopped during a single pass thru the go procedure
  current-light            ;; the currently selected light

  ;; patch agentsets
  intersections ;; agentset containing the patches that are intersections
  roads         ;; agentset containing the patches that are roads

  horizlist
  verlist
  downlist
  uplist
  leftlist
  rightlist

  start-of-roads
  destination
  turnpoint
  event-taxis
  taxi-arrive-timer
  taxi-arrive-per-sec
  d1
  d2
  current-phase
  avg-speed  ;;list of avg speed
  hour-avg-speed  ;;avg of the last hour

  ;;event-taxi-increase

  grid-size-x
  grid-size-y
]

breed [cars car]



cars-own
[
  speed     ;; the speed of the turtle
  wait-time ;; the amount of time since the last time a turtle has moved
  direction  ;; 1up, 2down, 3left, 4right
  taxi?  ;;is taxi or not
  event-taxi?
  dropped-off?
  cars-ahead
  mark
]

turtles-own
[

]

patches-own
[
  intersection?   ;; true if the patch is at the intersection of two roads
  green-light-up? ;; true if the green light is above the intersection.  otherwise, false.
                  ;; false for a non-intersection patches.
  my-row          ;; the row of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  my-column       ;; the column of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  my-phase        ;; the phase for the intersection.  -1 for non-intersection patches.
  auto?           ;; whether or not this intersection will switch automatically.
                  ;; false for non-intersection patches.

  dir  ;;1vertical or 2horizontal
  dir2 ;; 1 donw, 2up, 3left, 4right
  edge? ;;on edge

]



;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;

;; Initialize the display by giving the global and patch variables initial values.
;; Create num-cars of turtles if there are enough road patches for one turtle to
;; be created per road patch. Set up the plots.
to setup
  clear-all

  if show-real-map[
    import-drawing "map8.png"]

  ;import-pcolors-rgb "map.png"

  setup-globals
  set taxi-arrive-timer 0

  ;; First we ask the patches to draw themselves and set up a few variables
  setup-patches

  make-current one-of intersections
  label-current

  set-default-shape cars "car top"

  if (num-cars > count roads)
  [
    user-message (word "There are too many cars for the amount of "
                       "road.  Either increase the amount of roads "
                       "by increasing the GRID-SIZE-X or "
                       "GRID-SIZE-Y sliders, or decrease the "
                       "number of cars by lowering the NUMBER slider.\n"
                       "The setup has stopped.")
    stop
  ]


  ;; Now create the turtles and have each created turtle call the functions setup-cars and set-car-color
  create-cars num-cars
  [
    setup-cars
    ;set-car-color
    record-data
  ]

  ;; give the turtles an initial speed
  ask cars [ set-car-speed ]

  ask patch -4 1 [sprout 1 [set shape "house two story" set size 5 set color 127]]
  set destination one-of turtles with [shape = "house two story"]

  ask patches with [pxcor = max-pxcor or pxcor = min-pxcor or pycor = max-pycor or pycor = min-pycor][set edge? true]

  reset-ticks


end

;; Initialize the global variables to appropriate values
to setup-globals

  set avg-speed []
  set current-phase 0
  set current-light nobody ;; just for now, since there are no lights yet
  set phase 0
  set num-cars-stopped 0
  set grid-size-x 3
  set grid-size-y 10
  set grid-x-inc world-width / grid-size-x
  set grid-y-inc world-height / grid-size-y

  ;; don't make acceleration 0.1 since we could get a rounding error and end up on a patch boundary
  set acceleration 0.099
end

;; Make the patches have appropriate colors, set up the roads and intersections agentsets,
;; and initialize the traffic lights to one setting
to setup-patches
  ;; initialize the patch-owned variables and color the patches to a base-color
  ask patches
  [
    set intersection? false
    set auto? false
    set green-light-up? true
    set my-row -1
    set my-column -1
    set my-phase -1
    set pcolor brown + 3
  ]

  ;; initialize the global variables that hold patch agentsets
  let candidates patches with [not (pycor = 1 and (pxcor >= -21 and pxcor <= 6) )]
  set roads candidates with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) or
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]

  ask patch -8 1 [set pcolor white]


  set verlist []
  set downlist []
  set uplist []


  ask patches with [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0)]
  [set verlist lput pxcor verlist]

  set verlist  sort remove-duplicates verlist

  let i 1
  foreach verlist
  [x -> ifelse i mod 2 = 1
    [set uplist lput x uplist set i i + 1] [set downlist lput x downlist set i i + 1]
  ]



  set horizlist []
  set leftlist []
  set rightlist []


  ask patches with [ (floor((pycor + max-pycor) mod grid-y-inc) = 0)]
  [set horizlist lput pycor horizlist]

  set horizlist sort remove-duplicates horizlist

  let j 1
  foreach horizlist
  [x -> ifelse j mod 2 = 0
     [set rightlist lput x rightlist set j j + 1][set leftlist lput x leftlist set j j + 1]
  ]

  ask roads with [member? pycor horizlist and member? pxcor downlist][ ask patch-at 0 1 [set intersection? true set dir 1]]
  ask roads with [member? pycor horizlist and member? pxcor uplist][ask patch-at 0 -1 [set intersection? true set dir 1]]
  ask roads with [member? pxcor verlist and member? pycor leftlist][ask patch-at 1 0 [set intersection? true set dir 2]]
  ask roads with [member? pxcor verlist and member? pycor rightlist][ask patch-at -1 0 [set intersection? true set dir 2]]
  set intersections roads with [intersection? = true]


  set turnpoint roads with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) and
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]

  ask roads [ set pcolor white ]
  setup-intersections
end

;; Give the intersections appropriate values for the intersection?, my-row, and my-column
;; patch variables.  Make all the traffic lights start off so that the lights are red
;; horizontally and green vertically.
to setup-intersections
  ask intersections
  [
    set green-light-up? true
    set my-phase 0
    set auto? true
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
    set-signal-colors
  ]
end

;; Initialize the turtle variables to appropriate values and place the turtle on an empty road patch.
to setup-cars  ;; turtle procedure
  set speed 0
  set wait-time 0
  ;set shape "car"
  set color blue

  put-on-empty-road


  if member? xcor  downlist[
    set direction 2
    set heading 180
  ]


  if member? xcor uplist[
    set direction 1
    set heading 0
  ]


  if member? ycor leftlist[
    set direction 3
    set heading -90
  ]


  if member? ycor rightlist[
    set direction 4
    set heading 90
  ]

  if ycor = 1 [set mark 1]

end



to setup-taxi2  ;;event taxis
  set speed 0
  set wait-time 0
  ;set shape "car"
  set color yellow

  set event-taxi? true
  set dropped-off? false

  move-to one-of roads with [count turtles-here = 0 and not member? self turnpoint and distance destination > 15]


  if member? xcor  downlist[
    set direction 2
    set heading 180
  ]


  if member? xcor uplist[
    set direction 1
    set heading 0
  ]


  if member? ycor leftlist[
    set direction 3
    set heading -90
  ]


  if member? ycor rightlist[
    set direction 4
    set heading 90
  ]


end




;; Find a road patch without any turtles on it and place the turtle there.
to put-on-empty-road  ;; turtle procedure
  move-to one-of roads with [count cars-here = 0]
end


;;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Run the simulation
to go

  update-current

  ;; have the intersections change their color
  set-signals
  set num-cars-stopped 0

  ;;event taxi arrivals
  if taxi-arrive-timer > 0
  [
    if taxi-arrive-per-sec >= 1[
        create-cars taxi-arrive-per-sec [setup-taxi2]]
    if taxi-arrive-per-sec < 1 and random-float 1 <= taxi-arrive-per-sec [
        create-cars 1 [setup-taxi2]]

  set event-taxis cars with [event-taxi? = true]

  set taxi-arrive-timer taxi-arrive-timer - 1
  ]

  ;; set the turtles speed for this time thru the procedure, move them forward their speed,
  ;; record data for plotting, and set the color of the turtles to an appropriate color
  ;; based on their speed
  ask cars with [event-taxi? = true ] [

    if distance destination <= 5 [set dropped-off? true] ;;drop off customers
    if dropped-off? = true and [edge?] of patch-ahead 1 = true [die]  ;;leave map
    ifelse dropped-off? = false [turnright turnleft][turnright2 turnleft2]

  ]


  ask cars [if patch-here = patch 21 1 and direction = 4 [
  move-to patch-here set heading 0 set direction 1 ]]

  ask cars with [mark = 1][if member? patch-here patches with [edge? = true] [move-to patch 7 21 set heading 180 set direction 2 ]]
  ask cars with [mark = 1][if patch-here = patch 7 1 [move-to patch 7 1 set heading 90 set direction 4 ]]

  ask cars[set-car-speed]

  ask cars [fd speed record-data]

  set avg-speed lput  (mean [speed] of cars)  avg-speed

  if length avg-speed > 360 [set avg-speed remove first avg-speed avg-speed]

  set hour-avg-speed mean avg-speed

  ;; update the phase and the global clock
  next-phase
  tick

end

to event-taxi-arrivals
  ;;set event-taxi-increase (z-random-triangular dmin dmode dmax) * 100
  ;;print(event-taxi-increase)
  set taxi-arrive-timer 3600  ;;these taxis will arrive in the following 3600 * n seconds
  let temp floor (num-cars * event-taxi-increase * 0.01 / 3600)
  ifelse temp > 0 [set taxi-arrive-per-sec  temp]
  [set taxi-arrive-per-sec (num-cars * event-taxi-increase * 0.01 / 3600)]

end




to turnright
  let can-turn-right 0
  if member? patch-here turnpoint [
    if direction = 1 and member? [pycor] of patch-here rightlist  [set can-turn-right 1]
    if direction = 2 and member? [pycor] of patch-here leftlist  [set can-turn-right 1]
    if direction = 3 and member? [pxcor] of patch-here uplist  [set can-turn-right 1]
    if direction = 4 and member? [pxcor] of patch-here downlist [set can-turn-right 1] ]

  if can-turn-right = 1 [
    move-to patch-here
    ask patch-ahead 1 [set d1 distance destination ]
    ask patch-right-and-ahead 90 1 [set d2 distance destination]
    if d2 < d1 [
      if direction = 1 and member? [pycor] of patch-here rightlist  [move-to patch-here set heading 90 set direction 4]
      if direction = 2 and member? [pycor] of patch-here leftlist  [move-to patch-here set heading -90 set direction 3]
      if direction = 3 and member? [pxcor] of patch-here uplist  [move-to patch-here set heading 0 set direction 1]
      if direction = 4 and member? [pxcor] of patch-here downlist [move-to patch-here set heading 180 set direction 2]
    ]
]

end


to turnleft
  let can-turn 0
  if member? patch-here turnpoint [
    if direction = 1 and member? [pycor] of patch-here leftlist  [set can-turn 1]
    if direction = 2 and member? [pycor] of patch-here rightlist  [set can-turn 1]
    if direction = 3 and member? [pxcor] of patch-here downlist  [set can-turn 1]
    if direction = 4 and member? [pxcor] of patch-here uplist [set can-turn 1] ]

  if can-turn = 1 [
    move-to patch-here
    ask patch-ahead 1 [set d1 distance destination ]
    ask patch-left-and-ahead 90 1 [set d2 distance destination]
    if d2 < d1 [
      if direction = 1 and member? [pycor] of patch-here leftlist  [move-to patch-here set heading -90 set direction 3]
      if direction = 2 and member? [pycor] of patch-here rightlist  [move-to patch-here set heading 90 set direction 4]
      if direction = 3 and member? [pxcor] of patch-here downlist  [move-to patch-here set heading 180 set direction 2]
      if direction = 4 and member? [pxcor] of patch-here uplist [move-to patch-here set heading 0 set direction 1]
    ]
]

end

to turnright2
  let can-turn-right 0
  if member? patch-here turnpoint [
    if direction = 1 and member? [pycor] of patch-here rightlist  [set can-turn-right 1]
    if direction = 2 and member? [pycor] of patch-here leftlist  [set can-turn-right 1]
    if direction = 3 and member? [pxcor] of patch-here uplist  [set can-turn-right 1]
    if direction = 4 and member? [pxcor] of patch-here downlist [set can-turn-right 1] ]

  if can-turn-right = 1 [
    if random-float 1 <= 0.5 [
      if direction = 1 and member? [pycor] of patch-here rightlist  [move-to patch-here set heading 90 set direction 4]
      if direction = 2 and member? [pycor] of patch-here leftlist  [move-to patch-here set heading -90 set direction 3]
      if direction = 3 and member? [pxcor] of patch-here uplist  [move-to patch-here set heading 0 set direction 1]
      if direction = 4 and member? [pxcor] of patch-here downlist [move-to patch-here set heading 180 set direction 2]
    ]
]

end


to turnleft2
  let can-turn 0
  if member? patch-here turnpoint [
    if direction = 1 and member? [pycor] of patch-here leftlist  [set can-turn 1]
    if direction = 2 and member? [pycor] of patch-here rightlist  [set can-turn 1]
    if direction = 3 and member? [pxcor] of patch-here downlist  [set can-turn 1]
    if direction = 4 and member? [pxcor] of patch-here uplist [set can-turn 1] ]

  if can-turn = 1 [
    if random-float 1 <= 0.5 [
      if direction = 1 and member? [pycor] of patch-here leftlist  [move-to patch-here set heading -90 set direction 3]
      if direction = 2 and member? [pycor] of patch-here rightlist  [move-to patch-here set heading 90 set direction 4]
      if direction = 3 and member? [pxcor] of patch-here downlist  [move-to patch-here set heading 180 set direction 2]
      if direction = 4 and member? [pxcor] of patch-here uplist [move-to patch-here set heading 0 set direction 1]
    ]
]

end


to choose-current
  if mouse-down?
  [
    let x-mouse mouse-xcor
    let y-mouse mouse-ycor
    if [intersection?] of patch x-mouse y-mouse
    [
      update-current
      unlabel-current
      make-current patch x-mouse y-mouse
      label-current
      stop
    ]
  ]
end

;; Set up the current light and the interface to change it.
to make-current [light]
  set current-light light
  set current-phase [my-phase] of current-light
  ;set current-auto? [auto?] of current-light
end

;; update the variables for the current light
to update-current
  ask current-light [
    set my-phase current-phase
    set auto? True
  ]
end

;; label the current light
to label-current

end

;; unlabel the current light (because we've chosen a new one)
to unlabel-current
  ask current-light
  [
    ask patch-at -1 1
    [
      set plabel ""
    ]
  ]
end

;; have the traffic lights change color if phase equals each intersections' my-phase
to set-signals
  if phase >= ticks-per-cycle - 2 [ask intersections with [pcolor = green][set pcolor orange]]

  ask intersections with [auto? and phase = floor ((my-phase * ticks-per-cycle) / 100)]
  [
    set green-light-up? (not green-light-up?)
    set-signal-colors
  ]
end

;; This procedure checks the variable green-light-up? at each intersection and sets the
;; traffic lights to have the green light up or the green light to the left.
to set-signal-colors  ;; intersection (patch) procedure

    ifelse green-light-up?
    [ifelse dir = 1 [set pcolor green][set pcolor red ]]
    [ifelse dir = 2 [set pcolor green][set pcolor red ]]


end

;; set the turtles' speed based on whether they are at a red traffic light or the speed of the
;; turtle (if any) on the patch in front of them
to set-car-speed  ;; turtle procedure
  ifelse pcolor = red or pcolor = orange
  [ set speed 0 ]
  [
    if direction = 1 [ set-speed 0 1 ]
    if direction = 2 [ set-speed 0 -1 ]
    if direction = 3 [ set-speed -1 0 ]
    if direction = 4 [ set-speed 1 0 ]

  ]

end

;; set the speed variable of the car to an appropriate value (not exceeding the
;; speed limit) based on whether there are cars on the patch in front of the car
to set-speed [ delta-x delta-y ]  ;; turtle procedure
  ;; get the turtles on the patch in front of the turtle
  set cars-ahead cars-at delta-x delta-y

  ;; if there are turtles in front of the turtle, slow down
  ;; otherwise, speed up
  ifelse any? cars-ahead
  [
    ifelse any? (cars-ahead with [ direction != [direction] of myself ]) [
      let blocking-cars cars-ahead with [ direction != [direction] of myself]
      ask blocking-cars [fd -0.5] ;;ask cars that block the intersactions to move backward
      speed-up
      ]
    [
      set speed [speed] of one-of cars-ahead
      slow-down
    ]
  ]
  [ speed-up ]
end

;; decrease the speed of the turtle
to slow-down  ;; turtle procedure
  set speed speed - acceleration
  if speed <= 0  [ set speed 0 ];;if speed < 0

end

;; increase the speed of the turtle
to speed-up  ;; turtle procedure
  ;;cell size = 100 ft by 100 ft
  ;;1 tick = 1 second
  ;;speed is in mph. 1 mph = 1.46667 feet per second = 0.014667 cell per second

  ifelse speed > speed-limit * 0.014667
  [ set speed speed-limit * 0.014667]
  [ set speed speed + acceleration ]
end

;; set the color of the turtle to a different color based on how fast the turtle is moving
to set-car-color  ;; turtle procedure
  ifelse speed < (speed-limit * 0.014667 / 2)
  [ set color blue ]
  [ set color cyan - 2 ]
end

;; keep track of the number of stopped turtles and the amount of time a turtle has been stopped
;; if its speed is 0
to record-data  ;; turtle procedure
  ifelse speed = 0
  [
    set num-cars-stopped num-cars-stopped + 1
    set wait-time wait-time + 1
  ]
  [ set wait-time 0 ]
end

to change-current
  ask current-light
  [
    set green-light-up? (not green-light-up?)
    set-signal-colors
  ]
end

;; cycles phase to the next appropriate value
to next-phase
  ;; The phase cycles from 0 to ticks-per-cycle, then starts over.
  set phase phase + 1
  if phase mod ticks-per-cycle = 0
    [ set phase 0 ]
end

to-report z-random-triangular [#min #mode #max]
  ;;if not (#min < #mode and #mode < #max) [error "Triangular Distribution parameters are in the wrong order"]

  let FC ((#mode - #min) / (#max - #min))
  let U random-float 1
  ifelse U < FC [

    report (#min + (sqrt (U * (#max - #min) * (#mode - #min))))
  ]
  [
    report (#max - (sqrt ((1 - U ) * (#max - #min) * (#max - #mode))))
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
219
10
778
570
-1
-1
12.814
1
12
1
1
1
0
1
1
1
-21
21
-21
21
1
1
1
ticks
30.0

PLOT
1435
75
1833
332
Average Wait Time of Cars
Time
Average Wait
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [wait-time] of cars"

PLOT
1096
71
1422
329
Average Speed of Cars
Time
Average Speed
0.0
1.0
0.0
1.0
true
false
";;set-plot-y-range 0 speed-limit" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (mean [speed] of cars) / 0.014667"

SLIDER
22
110
182
143
num-cars
num-cars
1
500
300.0
1
1
NIL
HORIZONTAL

PLOT
812
341
1084
573
Stopped Cars
Time
Stopped Cars
0.0
100.0
0.0
100.0
true
false
"set-plot-y-range 0 num-cars" ""
PENS
"default" 1.0 0 -16777216 true "" "plot num-cars-stopped"

BUTTON
19
49
93
82
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
19
10
103
43
Setup
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

SLIDER
22
188
177
221
speed-limit
speed-limit
10
50
30.0
1
1
mph
HORIZONTAL

MONITOR
811
11
916
56
Current Phase
phase
3
1
11

SLIDER
21
149
177
182
ticks-per-cycle
ticks-per-cycle
1
500
120.0
1
1
NIL
HORIZONTAL

BUTTON
27
330
161
363
NIL
event-taxi-arrivals
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1430
340
1837
569
Number of event taxis on map
Time
Event Taxis
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count cars with [event-taxi? = true]"

BUTTON
102
51
165
84
NIL
Go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1089
337
1426
567
Number of cars on map
Time
All cars
0.0
10.0
100.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count cars"

SWITCH
24
233
162
266
show-real-map
show-real-map
1
1
-1000

PLOT
811
71
1090
324
Average Speed of cars near destination
Time
Average Speed
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (mean [speed] of cars with [distance destination <= 10]) / 0.014667"

INPUTBOX
28
392
99
452
dmin
0.2
1
0
Number

TEXTBOX
31
371
181
389
Parameters for the distribution
11
0.0
1

INPUTBOX
113
392
191
452
dmax
1.0
1
0
Number

INPUTBOX
29
461
119
521
dmode
0.5
1
0
Number

SLIDER
25
279
199
312
event-taxi-increase
event-taxi-increase
0
200
139.6
1
1
%
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This is a model of traffic moving in a city grid. It  also simulates event impact on traffic.

## HOW IT WORKS

Each time step, the cars attempt to move forward at their current speed.  If their current speed is less than the speed limit and there is no car directly in front of them, they accelerate.  If there is a slower car in front of them, they match the speed of the slower car and deccelerate.  If there is a red light or a stopped car in front of them, they stop.

Press the event-taxi-arrivals button to start an event, and event taxis will be arriving.


## RELATED MODELS

- "Traffic Basic": a simple model of the movement of cars on a highway.

- "Traffic Basic Utility": a version of "Traffic Basic" including a utility function for the cars.

- "Traffic Basic Adaptive": a version of "Traffic Basic" where cars adapt their acceleration to try and maintain a smooth flow of traffic.

- "Traffic Basic Adaptive Individuals": a version of "Traffic Basic Adaptive" where each car adapts individually, instead of all cars adapting in unison.

- "Traffic 2 Lanes": a more sophisticated two-lane version of the "Traffic Basic" model.

- "Traffic Intersection": a model of cars traveling through a single intersection.

- "Traffic Grid Goal": a version of "Traffic Grid" where the cars have goals, namely to drive to and from work.

- "Gridlock HubNet": a version of "Traffic Grid" where students control traffic lights in real-time.

- "Gridlock Alternate HubNet": a version of "Gridlock HubNet" where students can enter NetLogo code to plot custom metrics.



## COPYRIGHT AND LICENSE

This is built based on NetLogo Traffic Grid model.

Wilensky, U. (2003). NetLogo Traffic Grid model. http://ccl.northwestern.edu/netlogo/models/TrafficGrid. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
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
true
0
Polygon -7500403 true true 180 15 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 285 165 285 225 285 225 15 180 15
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

car top
true
0
Polygon -7500403 true true 151 8 119 10 98 25 86 48 82 225 90 270 105 289 150 294 195 291 210 270 219 225 214 47 201 24 181 11
Polygon -16777216 true false 210 195 195 210 195 135 210 105
Polygon -16777216 true false 105 255 120 270 180 270 195 255 195 225 105 225
Polygon -16777216 true false 90 195 105 210 105 135 90 105
Polygon -1 true false 205 29 180 30 181 11
Line -7500403 false 210 165 195 165
Line -7500403 false 90 165 105 165
Polygon -16777216 true false 121 135 180 134 204 97 182 89 153 85 120 89 98 97
Line -16777216 false 210 90 195 30
Line -16777216 false 90 90 105 30
Polygon -1 true false 95 29 120 30 119 11

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

house two story
false
0
Polygon -7500403 true true 2 180 227 180 152 150 32 150
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 75 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 90 150 135 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Rectangle -7500403 true true 15 180 75 255
Polygon -7500403 true true 60 135 285 135 240 90 105 90
Line -16777216 false 75 135 75 180
Rectangle -16777216 true false 30 195 93 240
Line -16777216 false 60 135 285 135
Line -16777216 false 255 105 285 135
Line -16777216 false 0 180 75 180
Line -7500403 true 60 195 60 240
Line -7500403 true 154 195 154 255

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>if ticks = 2000
[event-taxi-arrivals]</final>
    <timeLimit steps="5001"/>
    <exitCondition>ticks = 5000</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-taxis">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-duration">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="current-auto?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s1" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-taxis">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-duration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="current-auto?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s2" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-taxis">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-duration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="current-auto?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage-taxis">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-duration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="current-auto?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s4" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="13.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s5" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="13.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s6" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="13.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s7" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="42.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s8" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="42.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s9" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="42.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s10" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="139.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s11" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="139.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="s12" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go
if ticks = 3600[
event-taxi-arrivals]</go>
    <exitCondition>ticks = 10800</exitCondition>
    <metric>hour-avg-speed /  0.014667</metric>
    <metric>mean [wait-time] of cars</metric>
    <metric>(mean [speed] of cars) / 0.014667</metric>
    <metric>(mean [speed] of cars with [distance destination &lt;= 10]) / 0.014667</metric>
    <metric>num-cars-stopped</metric>
    <metric>count cars</metric>
    <metric>count cars with [event-taxi? = true]</metric>
    <enumeratedValueSet variable="grid-size-y">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size-x">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="event-taxi-increase">
      <value value="139.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-cycle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-real-map">
      <value value="false"/>
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
