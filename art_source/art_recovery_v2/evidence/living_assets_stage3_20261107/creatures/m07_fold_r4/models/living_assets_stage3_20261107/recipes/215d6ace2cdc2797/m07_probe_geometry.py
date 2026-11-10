"""Pure narrow phase used only by the unrun M07 retained-rig probe."""
import numpy as np
EPS=1e-12
def tri(value):
 a=np.asarray(value,dtype=float)
 if a.shape!=(3,3) or not np.isfinite(a).all():raise ValueError('Finite triangle required')
 if np.linalg.norm(np.cross(a[1]-a[0],a[2]-a[0]))<=EPS:raise ValueError('Degenerate triangle')
 return a
def point_triangle(point,t):
 p=np.asarray(point,dtype=float);a,b,c=t;ab=b-a;ac=c-a;ap=p-a
 d1=np.dot(ab,ap);d2=np.dot(ac,ap)
 if d1<=0 and d2<=0:return float(np.linalg.norm(ap))
 bp=p-b;d3=np.dot(ab,bp);d4=np.dot(ac,bp)
 if d3>=0 and d4<=d3:return float(np.linalg.norm(bp))
 vc=d1*d4-d3*d2
 if vc<=0 and d1>=0 and d3<=0:return float(np.linalg.norm(p-(a+ab*d1/(d1-d3))))
 cp=p-c;d5=np.dot(ab,cp);d6=np.dot(ac,cp)
 if d6>=0 and d5<=d6:return float(np.linalg.norm(cp))
 vb=d5*d2-d1*d6
 if vb<=0 and d2>=0 and d6<=0:return float(np.linalg.norm(p-(a+ac*d2/(d2-d6))))
 va=d3*d6-d5*d4
 if va<=0 and d4-d3>=0 and d5-d6>=0:return float(np.linalg.norm(p-(b+(c-b)*(d4-d3)/((d4-d3)+(d5-d6)))))
 denom=1/(va+vb+vc);q=a+ab*vb*denom+ac*vc*denom
 return float(np.linalg.norm(p-q))
def segment_segment(p1,q1,p2,q2):
 d1=q1-p1;d2=q2-p2;r=p1-p2
 a=np.dot(d1,d1);e=np.dot(d2,d2);f=np.dot(d2,r)
 if a<=EPS and e<=EPS:return float(np.linalg.norm(r))
 if a<=EPS:s=0;t=np.clip(f/e,0,1)
 else:
  c=np.dot(d1,r)
  if e<=EPS:t=0;s=np.clip(-c/a,0,1)
  else:
   b=np.dot(d1,d2);denom=a*e-b*b
   s=np.clip((b*f-c*e)/denom,0,1) if abs(denom)>EPS else 0
   t=(b*s+f)/e
   if t<0:t=0;s=np.clip(-c/a,0,1)
   elif t>1:t=1;s=np.clip((b-c)/a,0,1)
 return float(np.linalg.norm((p1+d1*s)-(p2+d2*t)))
def segment_hits(p,q,t):
 a,b,c=t;normal=np.cross(b-a,c-a);direction=q-p;denom=np.dot(normal,direction)
 if abs(denom)<=EPS:return False
 fraction=np.dot(normal,a-p)/denom
 if fraction<0 or fraction>1:return False
 hit=p+direction*fraction
 return point_triangle(hit,t)<=1e-10
def triangle_distance(first,second):
 a,b=tri(first),tri(second)
 for source,target in ((a,b),(b,a)):
  if any(segment_hits(source[i],source[(i+1)%3],target) for i in range(3)):return 0.0
 distance=min([point_triangle(v,b) for v in a]+[point_triangle(v,a) for v in b])
 for i in range(3):
  for j in range(3):distance=min(distance,segment_segment(a[i],a[(i+1)%3],b[j],b[(j+1)%3]))
 if not np.isfinite(distance):raise ValueError('Nonfinite separation')
 return max(0.,distance)

