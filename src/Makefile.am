# Makefile.am for squidguard/src

yncludedir = @yncludedir@/squidguard

client_DATA =			\
	squidguard.ycp		\
	squidguard_auto.ycp	\
	squidguard_proposal.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	complex.ycp

desktop_DATA =			\
	squidguard.desktop

module_DATA =			\
	Squidguard.ycp		\
	Squidguard2.pm

# create a symlink for local build, #145327
squidguard:
	ln -sf . $@
ycpchook = squidguard

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
