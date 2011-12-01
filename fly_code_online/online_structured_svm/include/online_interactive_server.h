#ifndef __SERVER_H
#define __SERVER_H

#include "structured_svm.h"
#include "jsonrpc.h"

#include <json/json.h>
#include <cstdio>
#include <cstdlib>
#include <csignal>

#include <omp.h>

#define MAX_SESSIONS 20

/**
 * @struct Session
 * @brief Caches memory for a network session.  
 *
 * For example, if a person is interactively
 *   classifying an example x, it may be convenient to keep x cached in memory as the
 *   client sends repeated commands over the network
 */
typedef struct {
  StructuredExample *example; /**< A memory cache of the example */
  StructuredLabel *partial_label;  /**< The last partial label specified by the user */

  char *id;   /**< a unique id for this session */
  unsigned long timestamp;  /**< a timestep when this session was last accessed */
  omp_lock_t lock;  /**< synchronizes access to this session's memory */
} Session;


/**
 * @class StructuredLearnerRpc
 * @brief A class used to relay commands from a client over the network to an online structured
 *   learner in the process of training.  This is useful for dynamically adding new examples or
 *   interactively classifying examples while learning is in progress
 * 
 * In the documentation below, we describe the network protocol for each type of client request,
 * where "Client: <client_str>" means the client sends a string <client_str> to the server over a network
 * socket connection, and "Server: <server_str>" means the server sends a response string <server_str> back.  To
 * test this, you can do something like this from a unix prompt:
 *  - telnet localhost 8086
 *  -     <client_str>
 */
class StructuredLearnerRpc
{
protected:
  StructuredSVM *learner;
  unsigned long timestamp;
  JsonRpcServer *server;
  
  Session sessions[MAX_SESSIONS];  /**< a num_sessions array of pointers to sessions */
  int num_sessions;

  char session_dir[1000];
  omp_lock_t lock;

  char trainfile[1000], infile[1000];
  bool train;
public:

  /**
   * @brief Create a new StructuredLearnerRpc, where l defines the class used for structured learning
   */
  StructuredLearnerRpc(StructuredSVM *l);
  ~StructuredLearnerRpc();

  /**
   * @brief Begin running a server
   */
  int main(int argc, const char **argv) ;

protected:
  /**
   * @brief Add remote procedure methods
   *
   */
  virtual void AddMethods();

  /**
   * @brief Parse command line arguments
   *
   */
  virtual void parse_command_line_arguments(int argc, const char **argv);

  /**
   * @brief Add a new example to the training set
   *
   * The network protocol for adding a new example (x,y) where <string_encoding_of_x> and <string_encoding_of_y> are in
   * the format of StructuredData::read() and StructuredLabel::write() and <ind> is the index of the training example added:
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"add_example","x":"<string_encoding_of_x>","y":"<string_encoding_of_y>"}
   *  - Server: {"id":1,"session_id":"<session_id>","index":"<ind>"}
   *
   */
  virtual bool AddNewExample(const Json::Value& root, Json::Value& response);

  /**
   * @brief Classify an example x, which is specified by the client.  The server returns a predicted label y.  Takes an optional partial label
   *
   * The network protocol for a regular classification is (where <string_encoding_of_x> is in the format
   *  of StructuredData::read() and is specified by the client, and <string_encoding_of_y> is in the
   *  format of StructuredLabel::write() and is generated by the server:
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"classify_example","x":"<string_encoding_of_x>"}
   *  - Server: {"id":1,"session_id":"<session_id>","y":"<string_encoding_of_y>"}
   *
   * One can optionally do a sequence of classification requests on the same example, for interactive classification where <partial_label_n>
   *  are string encodings of partial labels specified by the client in the format of StructuredLabel::read().  The following example
   *  does 3 steps of interactive labeling then adds the example to the training set:
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"classify_example","x":"<string_encoding_of_x>"}
   *  - Server: {"id":1,"session_id":"<session_id>","y":"<string_encoding_of_y1>"}
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"classify_example","session_id":"<session_id>","partial_label":"<partial_label1>"}
   *  - Server: {"id":1,"session_id":"<session_id>","y":"<string_encoding_of_y2>"}
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"classify_example","session_id":"<session_id>","partial_label":"<partial_label2>"}
   *  - Server: {"id":1,"session_id":"<session_id>","y":"<string_encoding_of_y3>"}
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"add_example","session_id":"<session_id>","y":"<string_encoding_of_y3>"}
   *  ...
   *
   *
   */
  virtual bool ClassifyExample(const Json::Value& root, Json::Value& response);

  /**
   * @brief Save the current model for a training job in progress
   *
   * The network protocol is:
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"save","filename":"<filename>"}
   *  - Server: {"id":1}
   */
  virtual bool SaveCurrentModel(const Json::Value& root, Json::Value& response);

  /**
   * @brief Signal the current training algorithm to exit
   *
   * The network protocol is:
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"shutdown"}
   *  - Server: {"id":1}
   */
  virtual bool Shutdown(const Json::Value& root, Json::Value& response);

  /**
   * @brief Change a learning parameter C, lambda, or feature_scale
   *
   * The network protocol is:
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"set_parameter","C":<c>}
   *  - Server: {"id":1}
   */
  virtual bool SetParameter(const Json::Value& root, Json::Value& response);

  /**
   * @brief Evaluate a testset using the current model parameters
   *
   * The network protocol is:
   *  - Client: {"jsonrpc":"2.0","id":1,"method":"evaluate_testset","testset":<filename>}
   *  - Server: {"id":1,}
   */
  virtual bool EvaluateTestset(const Json::Value& root, Json::Value& response);

 protected:
  bool FindOrCreateSession(const Json::Value& root, Json::Value& response);
  
  int FindSession(const char *sess_id, bool lockSession=false);
  int FindSession(const Json::Value& root, Json::Value& response);
  void EvictSession(int ind=-1);
  void Lock() { omp_set_lock(&lock); }
  void Unlock() { omp_unset_lock(&lock); }
  void LockSession(int i) { omp_set_lock(&sessions[i].lock); }
  void UnlockSession(int i) { omp_unset_lock(&sessions[i].lock); }

  bool GetStatistics(const Json::Value& root, Json::Value& response);
  bool NewSession(const Json::Value& root, Json::Value& response);
  bool InitializeSession(const Json::Value& root, Json::Value& response);

  int RunServer(int port);

 protected:
  char paramfile[1000], testfile[1000], outfile[1000], predictionsfile[1000];
  int port;
  bool runServer;
};


#define JSON_ERROR(errStr, sess_ind) \
  fprintf(stderr, "%s\n", errStr); \
  response["error"] = std::string(errStr); \
  if(sess_ind >= 0) UnlockSession(sess_ind); \
  return false;


#endif
