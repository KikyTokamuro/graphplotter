package ifneeded uriencode 1.0 [list source [file join $dir uriencode.tcl]]
package ifneeded tinyfileutils 1.0 [list source [file join $dir tinyfileutils.tcl]]
package ifneeded can2svg 0.3 [list source [file join $dir can2svg.tcl]]
package ifneeded azure-theme 1.0 [list apply {{dir} {
    source [file join $dir "Azure-ttk-theme" azure.tcl]
    package provide azure-theme 1.0
}} $dir]
