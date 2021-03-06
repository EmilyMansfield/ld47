# Unknot - Ludum Dare 47 (Unsubmitted)

Try and untie some knots, because that's usually a relaxing activity, right?

Controls are left-click only, and the fewer moves taken the better your score,
like golf I guess.

Created for Ludum Dare 47 with the theme 'Stuck in a loop'. While the player
being stuck in a loop may spring to mind, the interpretation here is that it's
the objects in the games that are loops. They can't be broken apart, but they
can be unravelled.

## Running

You can play the game in a sufficiently modern browser at
https://emilymansfield.github.io/ld47/, or can run the game directly through
the Godot editor using the project files and exporting to HTML5.

This is my first project in the Godot game engine, and while I'm not sure if a
Ludum Dare is the least stressful way to learn a new tool, Godot seems pretty
easy to pick up!

## Technical Info

Written in Godot v3.2.2.

The font files Poppins-Regular.ttf and Poppins-SemiBold.ttf are distributed
according to the SIL Open Font License in the OFL.txt file.

The remaining files are provided under the Creative Commons Zero v1.0 Universal
license, included in the LICENSE file.

## Post-mortem

Unfortunately correctly handling intersections in all cases was too hard in the
time, there are outstanding bugs that make only relatively trivial puzzles
possible. These are illustrated in the first few levels, while the last is
incompletable as far as I know. I may come back and rewrite this with a more
thought-out strategy, with bugs squashed, since I'm pretty happy with the
premise and the overall execution, but the details are important here and sadly
they were not ironed out in time.