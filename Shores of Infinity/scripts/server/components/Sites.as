import sites;

tidy class Sites : Component_Sites, SiteContainer, Savable {
	Mutex mtx;
	array<Site@> sites;
	Site@ currentSite;
	uint nextSiteId = 0;

	void save(SaveFile& file) {
		file << nextSiteId;
		uint cnt = sites.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			file << sites[i];
	}

	void load(SaveFile& file) {
		file >> nextSiteId;
		uint cnt = 0;
		file >> cnt;
		sites.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			@sites[i] = Site();
			file >> sites[i];
		}
	}

	Site@ getSiteById(uint id) {
		for (uint i = 0, cnt = sites.length; i < cnt; ++i) {
			if (sites[i].id == id)
				return sites[i];
		}
		return null;
	}

	uint getSiteId(uint index) {
		auto@ site = sites[index];
		return site.id;
	}

	uint getSiteTypeId(uint siteId) {
		auto@ site = getSiteById(siteId);
		return site.type.id;
	}

	bool hasSite(uint id) {
		auto@ site = getSiteById(id);
		return site !is null;
	}

	void selectSite(uint id) {
		Lock lck(mtx);
		Site@ current = getSiteById(id);
		@currentSite = current;
		yield(current);
	}

	void refreshCurrentSite() {
		Lock lck(mtx);
		if (currentSite !is null)
			yield(currentSite);
	}

	uint get_siteCount() const {
		return sites.length;
	}

	void create(Site@ site) {
		site.id = nextSiteId++;
		sites.insertLast(site);
	}

	uint spawnSite(Object& owner, uint typeId) {
		auto@ site = Site();
		site.create(owner, typeId);
		create(site);
		return site.id;
	}

	void chooseSiteOption(Object& owner, uint siteId, uint optionId) {
		Lock lck(mtx);
		auto@ site = getSiteById(siteId);
		if (site !is null)
			site.choose(optionId);
	}

	void destroySite(Object& owner, uint siteId) {
		Lock lck(mtx);
		@currentSite = null;
		auto@ site = getSiteById(siteId);
		if (site !is null)
			sites.remove(site);
	}
	
	void destroySites(Object& owner) {
		Lock lck(mtx);
		for (uint i = 0, cnt = sites.length; i < cnt; ++i) {
			sites.remove(sites[i]);
		}
	}

	void addProgressToSite(Object& owner, Empire@ emp, uint siteId, float amount) {
		auto@ site = getSiteById(siteId);
		float p = 1.f;
		if (p >= 1.f) {
			notifySite(owner, emp, siteId, site.type.id);
		}
	}

	void notifySite(Object@ owner, Empire@ emp, uint siteId, uint typeId) {
		emp.notifySite(owner, siteId, typeId);
	}

	void writeSites(Message& msg) const {
		if(sites.length == 0) {
			msg.write0();
			return;
		}
		Lock lck(mtx);
		msg.write1();
		msg.writeSmall(sites.length);
		for(uint i = 0, cnt = sites.length; i < cnt; ++i)
			msg << sites[i];
	}
};
