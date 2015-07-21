function ArrayListeneer(be, f, index) {
	this.index = index;
	this.be = be;
	this.f = f;
	be.AddListener(this);					
}

ArrayListeneer.prototype.Update = function(data) {
	this.f.SetInstrution(this.index, data);
}

function ParsedView(be, parent, id, class_name) {
	var valueInput = '<input id="' + id + '"';
	valueInput+='" type="text">' ;
	$(parent).append(valueInput);
	var view = $('#' + id);
	$(view).addClass(class_name);

	this.view = view;
	this.be = be;
	view.val = be.data;
	be.AddListener(this);
	$(view).attr('readonly', '');
	var  t = this;
	view.bind('keyup', function(e) {
		console.log('this.view.id: ' + t.view.attr('id') + ', value: ' + $(t.view).val());
		t.be.Update(t, parseInt($(t.view).val(), 16));
	});
}

ParsedView.prototype.Update = function(data) {
	var str = '';
	var instruction;
	instruction = ParseInstruction(data);
	str = instruction.name;
	$(this.view).val(str);
}

function HexView(be, parent, id, class_name) {
	var valueInput = '<input id="' + id + '"';
	valueInput+='" type="text" value="' + $(parent).attr('data-code-value') + '">' ;
	$(parent).append(valueInput);
	var view = $('#' + id);
	$(view).addClass(class_name);

	this.view = view;
	this.be = be;
	view.val = be.data;
	be.AddListener(this);
	$(view).attr('maxlength', '8');
	var  t = this;
	view.bind('keyup', function(e) {
		var str = $(t.view).val();
		while (str.length < 8) {str = '0' + str};
//		 $(t.view).val(str);	 
		var data = [parseInt(str.substr(6, 2), 16), 
						parseInt(str.substr(4, 2), 16),
						parseInt(str.substr(2, 2), 16),
						parseInt(str.substr(0, 2), 16)];	
		t.be.Update(t, data);				
	});
}

function byteToHex(b) {
	var str = b.toString(16) ;
	while (str.length < 2) {str = '0' + str};
	return str;
}

HexView.prototype.Update = function(data) {
	var data_ = byteToHex(data[3]) +
						byteToHex(data[2]) + 
						byteToHex(data[1]) + 
						byteToHex(data[0]) ;
	$(this.view).val(data_);
}