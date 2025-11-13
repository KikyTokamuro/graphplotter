#!/usr/bin/env tclsh
package require Tk

set scriptDir [file dirname [file normalize [info script]]]
set contribDir [file join $scriptDir "contrib"]
lappend ::auto_path $contribDir

package require can2svg
package require azure-theme

namespace eval ::GraphPlotter {
    variable factor 32
    variable function "cos(2*x)"
    variable canvasWidth
    variable canvasHeight
    variable lastWidth
    variable lastHeight
    variable dx
    variable dy
    variable fun
    variable info ""
}

proc ::GraphPlotter::main {} {
    set_theme light

    ttk::frame .main
    pack .main -fill both -expand 1

    canvas .c -bg white -borderwidth 2 -highlightthickness 0
    pack .c -in .main -fill both -expand 1 -pady 5 -padx 5

    ttk::frame .bottom
    pack .bottom -fill x -side bottom -pady 10 -padx 10

    ttk::label .info -textvariable ::GraphPlotter::info -justify left
    pack .info -in .bottom -fill x -side top

    ttk::frame .controls
    pack .controls -in .bottom -fill x -side top

    ttk::label .controls.f_label -text "f(x) = "
    ttk::entry .controls.f_entry -textvariable ::GraphPlotter::function -width 20
    ttk::label .controls.zoom_label -text " Zoom: "
    ttk::entry .controls.fac_entry -textvariable ::GraphPlotter::factor -width 4
    ttk::button .controls.plus_btn -text " + " -command {::GraphPlotter::zoom .c 2.0}
    ttk::button .controls.minus_btn -text " - " -command {::GraphPlotter::zoom .c 0.5}
    ttk::button .controls.export_btn -text "Export" -command {::GraphPlotter::exportCanvas .c}

    grid .controls.f_label -row 0 -column 0 -sticky w
    grid .controls.f_entry -row 0 -column 1 -sticky ew -padx 2
    grid .controls.zoom_label -row 0 -column 2 -sticky w -padx 5
    grid .controls.fac_entry -row 0 -column 3 -sticky w -padx 2
    grid .controls.minus_btn -row 0 -column 4 -sticky w -padx 2
    grid .controls.plus_btn -row 0 -column 5 -sticky w -padx 2
    grid .controls.export_btn -row 0 -column 6 -sticky w -padx 2

    grid columnconfigure .controls 1 -weight 1

    bind .controls.f_entry <Return> {::GraphPlotter::plotf .c $::GraphPlotter::function}
    bind .controls.fac_entry <Return> {::GraphPlotter::zoom .c 1.0}

    bind .c <Motion> {::GraphPlotter::displayXY .info %x %y}

    bind .c <Configure> {after idle ::GraphPlotter::adjustScale}

    wm minsize . 600 400
    wm title . "Graph Plotter"

    set iconImage [image create photo -file [file join $::scriptDir "icon.gif"]]
    wm iconphoto . -default $iconImage

    update idletasks
    ::GraphPlotter::plotf .c $::GraphPlotter::function
}

proc ::GraphPlotter::displayXY {w cx cy} {
    if {![info exists ::GraphPlotter::dx] || ![info exists ::GraphPlotter::dy]} return

    set x [expr {double($cx - $::GraphPlotter::dx) / $::GraphPlotter::factor}]
    set y [expr {double(-$cy + $::GraphPlotter::dy) / $::GraphPlotter::factor}]
    set ::GraphPlotter::info [format "x=%.2f y=%.2f" $x $y]

    catch {
        $w config -fg [expr {abs([expr $::GraphPlotter::fun] - $y) < 0.01 ? "white" : "black"}]
    }
}

proc ::GraphPlotter::adjustScale {} {
    set width [winfo width .c]
    set height [winfo height .c]

    if {[info exists ::GraphPlotter::lastWidth] && [info exists ::GraphPlotter::lastHeight] &&
        $::GraphPlotter::lastWidth == $width && $::GraphPlotter::lastHeight == $height} {
        return
    }

    set ::GraphPlotter::lastWidth $width
    set ::GraphPlotter::lastHeight $height
    set ::GraphPlotter::canvasWidth $width
    set ::GraphPlotter::canvasHeight $height

    if {[info exists ::GraphPlotter::function]} {
        plotf .c $::GraphPlotter::function
    }
}

proc ::GraphPlotter::zoom {w howmuch} {
    set ::GraphPlotter::factor [expr {round($::GraphPlotter::factor * $howmuch)}]
    plotf $w $::GraphPlotter::function
}

proc ::GraphPlotter::plotf {w function} {
    set ::GraphPlotter::fun $function
    
    foreach {re subst} {
        " " ""
        x \$x
        Pi 3.141592653589793
        E  2.718281828459045
        Phi 1.618033988749895
    } {
        regsub -all $re $function $subst function
    }

    set ::GraphPlotter::info $function
    set ::GraphPlotter::fun $function

    if {[string length $function] == 0} {
	$w delete all
	plotaxis $w
	return
    }

    set segments [fun2points $::GraphPlotter::fun]
    plotline $w $segments green
}

proc ::GraphPlotter::fun2points {fun} {
    set from -100.0
    set to 100.0
    set step 0.1

    set segments {}
    set current_segment {}

    for {set x $from} {$x <= $to} {set x [expr {$x + $step}]} {
        set y [expr $fun]

        if {[info exists last_y] && abs($y - $last_y) > 50} {
            if {[llength $current_segment] >= 4} {
                lappend segments $current_segment
            }
            set current_segment {}
        }

        lappend current_segment $x $y
        set last_y $y
    }

    if {[llength $current_segment] >= 4} {
        lappend segments $current_segment
    }

    return $segments
}

proc ::GraphPlotter::plotaxis {w} {
    if {![info exists ::GraphPlotter::canvasWidth] || ![info exists ::GraphPlotter::canvasHeight]} {
        set ::GraphPlotter::canvasWidth [winfo width $w]
        set ::GraphPlotter::canvasHeight [winfo height $w]
    }

    set ::GraphPlotter::dx [expr {$::GraphPlotter::canvasWidth / 2}]
    set ::GraphPlotter::dy [expr {$::GraphPlotter::canvasHeight / 2}]

    $w create line 0 $::GraphPlotter::dy $::GraphPlotter::canvasWidth $::GraphPlotter::dy -tags axis -fill gray
    $w create line $::GraphPlotter::dx 0 $::GraphPlotter::dx $::GraphPlotter::canvasHeight -tags axis -fill gray

    for {set i -100} {$i <= 100} {incr i} {
        if {$i == 0} continue
        set x [expr {$::GraphPlotter::dx + $i * $::GraphPlotter::factor}]
        set y [expr {$::GraphPlotter::dy - $i * $::GraphPlotter::factor}]

        if {$x >= 0 && $x <= $::GraphPlotter::canvasWidth} {
            $w create line $x [expr {$::GraphPlotter::dy - 5}] $x [expr {$::GraphPlotter::dy + 5}] -tags axis -fill gray
        }
        if {$y >= 0 && $y <= $::GraphPlotter::canvasHeight} {
            $w create line [expr {$::GraphPlotter::dx - 5}] $y [expr {$::GraphPlotter::dx + 5}] $y -tags axis -fill gray
        }
    }
}

proc ::GraphPlotter::plotline {w segments color} {
    $w delete all

    plotaxis $w

    foreach segment $segments {
        if {[llength $segment] >= 4} {
            set canvas_segment {}
            foreach {x y} $segment {
                set cx [expr {$::GraphPlotter::dx + $x * $::GraphPlotter::factor}]
                set cy [expr {$::GraphPlotter::dy - $y * $::GraphPlotter::factor}]
                lappend canvas_segment $cx $cy
            }
            $w create line $canvas_segment -tags f -width 3 -fill $color -smooth true
        }
    }

    $w raise f
}

proc ::GraphPlotter::exportCanvas {w} {
    set filename [tk_getSaveFile \
        -title "Export Canvas as Image" \
        -filetypes {
            {"All files" *}
        } \
        -defaultextension ".svg" \
        -initialfile "graph.svg"]

    if {$filename ne ""} {
        if {[catch {
            can2svg::canvas2file $w $filename -height $::GraphPlotter::canvasHeight -width $::GraphPlotter::canvasWidth
        } errorMsg]} {
            tk_messageBox -icon error -message "Export failed: $errorMsg" -title "Export Error"
        } else {
            tk_messageBox -icon info -message "Exported to:\n$filename" -title "Export Success"
        }
    }
}

::GraphPlotter::main
