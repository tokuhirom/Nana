test:
	PERL5LIB=./util/:\$PERL5LIB  prove -l --source TRA --source EGTRA --source TCC -r -Ilib t/ t/*/*/*.tcc t/*/*/*.egtra
test2:
	./Build
	PERL5LIB=./util/:\$PERL5LIB  prove -Mblib -l --source TRA --source EGTRA --source TCC -r -Ilib t/tra/*.tra t/tra/*/*.tra
# t/*/*.tra

.PHONY: test
