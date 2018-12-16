from orbitals import OrbitalModule;

interface IConstruction {
  bool started { get const; }
  bool completed { get const; set; }
};

interface IOrbitalConstruction : IConstruction {
  const OrbitalModule@ module { get const; }
}
