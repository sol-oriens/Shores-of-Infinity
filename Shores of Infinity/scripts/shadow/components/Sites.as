import sites;

tidy class Sites : Component_Sites {
	Mutex mtx;
	array<Site> sites;
	Site@ currentSite;

	Site@ getSiteById(uint id) {
		for (uint i = 0, cnt = sites.length; i < cnt; ++i) {
			if (sites[i].id == id)
				return sites[i];
		}
		return null;
	}

	uint getSiteId(uint index) {
		Site@ site = sites[index];
		return site.id;
	}

	uint getSiteTypeId(uint siteId) {
		Site@ site = getSiteById(siteId);
		return site.type.id;
	}

	bool hasSite(uint id) {
		Site@ site = getSiteById(id);
		if (site !is null)
			return true;
		return false;
	}

	void selectSite(uint id) {
		Lock lck(mtx);
		Site@ current = getSiteById(id);
		yield(current);
	}

	void refreshCurrentSite() {
		Lock lck(mtx);
		if (currentSite !is null)
			yield(currentSite);
	}

	uint get_siteCount() {
		return sites.length;
	}

	void destroySite(Object& owner, uint siteId) {
		Lock lck(mtx);
		@currentSite = null;
		auto@ site = getSiteById(siteId);
		if (site !is null)
			sites.remove(site);
	}

	void readSites(Message& msg) {
		if(!msg.readBit()) {
			if(sites.length != 0) {
				Lock lck(mtx);
				sites.length = 0;
			}
			return;
		}
		Lock lck(mtx);
		sites.length = msg.readSmall();
		for(uint i = 0, cnt = sites.length; i < cnt; ++i)
			msg >> sites[i];
	}
};
