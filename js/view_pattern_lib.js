function DataBE(data) {
	this.listeners = [];
	this.data = data;
}

DataBE.prototype.AddListener = function(listener) {
	this.listeners.push(listener);
	listener.Update(this.data);
}

DataBE.prototype.Update = function (listener, data) {			
//Possible concurrency issue
	console.log('Got event ' + data + ' from ' + listener);
	this.data = data;
	for (var i=0; i<this.listeners.length; i++) {
		if (this.listeners[i] != listener) {
			this.listeners[i].Update(data);
		}
	}
}