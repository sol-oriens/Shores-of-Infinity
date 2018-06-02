//Calculates an estimated time of arrival similar to newtonArrivalTime but taking into account the light speed limitations
//This formula works only for distances where gamma has a significant effect and is less accurate than newtonArrivalTime for shorter distances
//For this reason the returned result is calculated by newtonArrivalTime in this case.
double einsteinArrivalTime(double acceleration, vec3d distance, vec3d velocity) {
  double a = acceleration;
  double d = distance.length;
  double v = velocity.length;
  double c = config::LIGHT_SPEED * config::SCALE_SPACING;

  //TODO: the formula to choose which method of calculation to use may be inaccurate and needs more test data
  //At c = 1000, the distance at which newtonArrivalTime and einsteinArrivalTime roughly give the same results is about 350,000 units
  //At c = 2000, the distance at which newtonArrivalTime and einsteinArrivalTime roughly give the same results is about 1,400,000 units
  if (sqrt(d) * 2 < c)
    return newtonArrivalTime(acceleration, distance, velocity);
  else
    return sqrt(sqr(d / c) + (2 * d / a));
}
