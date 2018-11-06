TEMP_DIR = "out"
test:
	mkdir $(TEMP_DIR)
	./jobgen --arch=ppc64le --compose=RHEL-7.2-0820.0 -m "model ~ Power" -w "ppc64le test" --staf-cmd="python ConfigTest.py" -o $(TEMP_DIR)/r7-ppc.xml

	./jobgen --arch=x86_64 --compose=RHEL-7.2-0820.0 --staf-cmd="python ConfigTest.py" -o $(TEMP_DIR)/r7-x86.xml
	./jobgen --arch=x86_64 -m "key_value.CPUFLAGS=vmx" --compose=RHEL-7.2-0820.0 --staf-cmd="python ConfigTest.py" -o $(TEMP_DIR)/r7-m-x86.xml
	./jobgen --arch=x86_64 -m "xxxx" --compose=RHEL-7.2-0820.0 --staf-cmd="python ConfigTest.py" -o $(TEMP_DIR)/unknown.xml

.PHONY: clean
clean:
	rm -rf $(TEMP_DIR)
